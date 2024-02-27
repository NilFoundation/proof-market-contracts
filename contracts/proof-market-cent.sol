// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

contract ProofMarket {

    address public admin;
    mapping(address => uint256) public balances;

    event Deposit(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amount);

    constructor() {
        admin = msg.sender;
    }

    function deposit() public payable {
        require(msg.value > 0, "Deposit must be greater than 0");
        balances[msg.sender] += msg.value;
        emit Deposit(msg.sender, msg.value);
    }

    function balanceOf(address user) public view returns (uint256) {
        return balances[user];
    }

    function withdraw(address payable user, uint256 amount) public {
        require(msg.sender == admin, "Only the admin can perform this action");
        require(balances[user] >= amount, "Insufficient balance");
        balances[user] -= amount;
        (bool sent,) = user.call{value: amount}("");
        require(sent, "Failed to send Ether");
        emit Withdraw(user, amount);
    }

    receive() external payable {
        deposit();
    }
}