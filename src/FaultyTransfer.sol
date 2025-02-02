// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.10;

contract ERC20 {
    event Transfer(address indexed _from, address indexed _to, uint256 _value);

    mapping(address owner => uint256 balance) private _balances;

    // assume that we check that `from` has proper allowance or ownership of the tokens
    function _transfer(address from, address to, uint256 amount) internal virtual {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");

        uint256 fromBalance = _balances[from];
        uint256 toBalance = _balances[to];

        require(fromBalance >= amount, "ERC20: transfer amount exceeds balance");
        unchecked {
            _balances[from] = fromBalance - amount;
            // Overflow not possible: the sum of all balances is capped by totalSupply, and the sum is preserved by
            // decrementing then incrementing.
            _balances[to] = toBalance + amount;
        }

        emit Transfer(from, to, amount);
    }
}

// NOTES: exploit when "from" and "to" are the same address
// e.g. calling _tranfer(0xabc, 0xabc, 100)
// let's assume current balalnce of 0xabc is 1000
// fromBalance = 1000
// toBalance = 1000
// _balances[0xabc] = 1000 - 100 = 900
// _balances[0xabc] = 1000 + 100 = 1100
// 0xabc can do this forever
