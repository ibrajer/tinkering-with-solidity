// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.10;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract AtomicSwapTimelock is Ownable {
    event SwapRequestSubmitted(
        address indexed sender,
        address indexed receiver,
        uint256 senderAmount,
        uint256 receiverAmount,
        bytes32 hashedSecret
    );
    event SwapRequestExecuted(
        address indexed sender, address indexed receiver, uint256 senderAmount, uint256 receiverAmount
    );
    event SwapRequestExpired(
        address indexed sender, address indexed receiver, uint256 senderAmount, uint256 receiverAmount
    );

    uint256 private timelockDeadline = 3600;
    address private senderTokenAddress;
    address private receiverTokenAddress;

    struct SwapRequest {
        address sender;
        address receiver;
        uint256 senderAmount;
        uint256 receiverAmount;
        bytes32 hashedSecret;
        uint256 timelockStart;
    }

    // both sender and receiver can submit the swap request, the first one to do it becomes "lockAddress"
    // this mapping keeps track of addresses that have the duty to unlock and execute swap request
    mapping(address unlockAddress => SwapRequest request) private requests;

    constructor(address _senderToken, address _receiverToken) Ownable(msg.sender) {
        require(_senderToken != address(0), "sender token can't be zero address");
        require(_receiverToken != address(0), "receiver token can't be zero address");
        senderTokenAddress = _senderToken;
        receiverTokenAddress = _receiverToken;

        // should probably check if those two addresses are really ERC20 tokens
        // but ERC20 doesn't support ERC165?
        // https://github.com/OpenZeppelin/openzeppelin-contracts/issues/3575
    }

    // not sure how useful, but a view function to check the status of the pending swap
    function checkSwapRequestStatus(address sender, address receiver) external view returns (SwapRequest memory) {
        SwapRequest memory request = requests[sender];
        if (request.hashedSecret != 0) {
            return request;
        }

        request = requests[receiver];
        if (request.hashedSecret != 0) {
            return request;
        }

        revert("swap request is not submitted");
    }

    // either sender or receiver can submit the atomic swap request, make sure that this contract has enough allowance and
    // that all other parameters are correct
    function submitSwapRequest(
        address sender,
        address receiver,
        uint256 senderAmount,
        uint256 receiverAmount,
        bytes32 hashedSecret
    ) external {
        require(sender != address(0), "sender can't be zero address");
        require(receiver != address(0), "receiver can't be zero address");
        require(hashedSecret != 0, "hashed secrets can't be zero bytes");
        // not sure if zero-value transfers are okay?
        require(senderAmount > 0, "sender amount can't be zero");
        require(receiverAmount > 0, "receiver amount can't be zero");
        require(msg.sender == sender || msg.sender == receiver, "submit request must come from sender or receiver");
        require(
            (msg.sender == sender && requests[receiver].hashedSecret == 0)
                || (msg.sender == receiver && requests[sender].hashedSecret == 0),
            "other side has already submitted request"
        );

        IERC20 senderToken = IERC20(senderTokenAddress);
        IERC20 receiverToken = IERC20(receiverTokenAddress);

        require(senderToken.allowance(sender, address(this)) >= senderAmount, "sender didn't set enough allowance");
        require(
            receiverToken.allowance(receiver, address(this)) >= receiverAmount, "receiver didn't set enough allowance"
        );

        // in case sender is submitting the swap request, prepare for the receiver to unlock it (and vice versa)
        if (msg.sender == sender) {
            requests[receiver] =
                SwapRequest(sender, receiver, senderAmount, receiverAmount, hashedSecret, block.timestamp);
        } else {
            requests[sender] =
                SwapRequest(receiver, receiver, senderAmount, receiverAmount, hashedSecret, block.timestamp);
        }

        emit SwapRequestSubmitted(receiver, receiver, senderAmount, receiverAmount, hashedSecret);
    }

    // the other side (the one that didn't submit the swap request) will have to execute it by providing the secret
    // but, there is a timelock involved which means if the time expires, the swap request will not be executed (and must be deleted)
    // submitting secret in raw format should still be safe, frontrunning attack wouldn't do any harm here?
    // it must be a raw secret otherwise the swap executor can't prove that it knows the secret (hashing must be done by the contract)
    function executeSwap(string memory secret) external {
        SwapRequest memory request = requests[msg.sender];
        require(msg.sender == request.sender || msg.sender == request.receiver, "must be sender or receiver");
        // we should probably put extra guards here, and limit secret hash comparison attempts, in case the attacker
        // has a way of "guessing" the secret using a small rainbow table, and the tx cost of multiple failure attempts
        // is way smaller than the potential reward if the swap would be successfull
        // if above this limit, the swap request will be discarded and sender will have to provide new secret
        // or should we allow submitting the secret only once? if incorrect secret is provided, treat this the same as expiration event?
        require(keccak256(abi.encode(secret)) == request.hashedSecret, "hash of the secret does not match");

        if (block.timestamp >= request.timelockStart + timelockDeadline) {
            // mark this pending swap as expired by deleting it
            delete requests[msg.sender];
            emit SwapRequestExpired(request.sender, request.receiver, request.senderAmount, request.receiverAmount);
            return;
        }

        // immediately remove the swap request before transfers
        delete requests[msg.sender];

        IERC20 senderToken = IERC20(senderTokenAddress);
        IERC20 receiverToken = IERC20(receiverTokenAddress);

        // another sanity check, in case sender and/or receiver had multiple parallel pending swaps
        require(
            senderToken.allowance(request.sender, address(this)) >= request.senderAmount,
            "sender didn't set enough allowance"
        );
        require(
            receiverToken.allowance(request.receiver, address(this)) >= request.receiverAmount,
            "receiver didn't set enough allowance"
        );

        SafeERC20.safeTransferFrom(senderToken, request.sender, request.receiver, request.senderAmount);
        SafeERC20.safeTransferFrom(receiverToken, request.receiver, request.sender, request.receiverAmount);

        emit SwapRequestExecuted(request.sender, request.receiver, request.senderAmount, request.receiverAmount);
    }

    // if the other side never managed to submit the secret, then the request will be stuck on the contract forever
    // this ensures that both sender and receiver are able to mark the request as expired, so that they can create a new one
    function expireWhenDeadline(address sender, address receiver) external {
        require(msg.sender == sender || msg.sender == receiver, "expiration request must come from sender or receiver");
        SwapRequest memory request = requests[sender];
        if (request.hashedSecret != 0 && block.timestamp >= request.timelockStart + timelockDeadline) {
            // mark this pending swap as expired by deleting it
            delete requests[msg.sender];
            emit SwapRequestExpired(request.sender, request.receiver, request.senderAmount, request.receiverAmount);
            return;
        }

        request = requests[receiver];
        if (request.hashedSecret != 0) {
            // mark this pending swap as expired by deleting it
            delete requests[msg.sender];
            emit SwapRequestExpired(request.sender, request.receiver, request.senderAmount, request.receiverAmount);
            return;
        }
    }

    // TODO
    // - this contract is not using good data structures that would enable parallel swaps by the same sender and receiver
    // (it is very restrictive right now)
    // - this contract lacks ability for the pending swap request to be terminated by the side that submitted it
    // (unless we want to treat this as "revokable" once submission is completed)
    // - this contracts lacks ability to remove all expired pending requests at once (executed only by the owner of the contract)
}
