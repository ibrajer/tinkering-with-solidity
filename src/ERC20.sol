// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.10;

contract ERC20 {
    event Transfer(address indexed _from, address indexed _to, uint256 _value);
    event Approval(address indexed _owner, address indexed _spender, uint256 _value);

    string public name;
    string public symbol;
    uint8 public decimals;
    uint256 public totalSupply;

    mapping(address owner => uint256 balance) private _balances;
    mapping(address owner => mapping(address spender => uint256 allowance)) private _allowances;

    constructor(string memory _name, string memory _symbol, uint8 _decimals, uint256 tokensAmount) {
        name = _name;
        symbol = _symbol;
        decimals = _decimals;
        totalSupply = tokensAmount * (10 ** _decimals);
    }

    function balanceOf(address _owner) public view returns (uint256 balance) {
        return _balances[_owner];
    }

    function transfer(address _to, uint256 _value) public returns (bool success) {
        // is self-transfer acceptable or not?
        //require(msg.sender != _to, "self-transfers not allowed")
        uint256 balance = _balances[msg.sender];
        require(_value <= balance, "balance too low");
        _balances[msg.sender] = balance - _value;
        _balances[_to] += _value;
        emit Transfer(msg.sender, _to, _value);
        return true;
    }

    function transferFrom(address _from, address _to, uint256 _value) public returns (bool success) {
        // is self-transfer acceptable or not?
        //require(_from != _to, "self-transfers not allowed")
        uint256 allowed = _allowances[_from][msg.sender];
        require(allowed > 0, "not allowed to transfer");
        require(_value <= allowed, "allowance not enough");
        uint256 balance = _balances[_from];
        require(_value <= balance, "source balance not enough");
        _balances[_from] = balance - _value;
        _balances[_to] += _value;
        _allowances[_from][msg.sender] = allowed - _value;
        emit Transfer(_from, _to, _value);
        return true;
    }

    function approve(address _spender, uint256 _value) public returns (bool success) {
        require(msg.sender != _spender, "spender and owner are the same");
        _allowances[msg.sender][_spender] = _value;
        emit Approval(msg.sender, _spender, _value);
        return true;
    }

    function allowance(address _owner, address _spender) public view returns (uint256 remaining) {
        return _allowances[_owner][_spender];
    }
}
