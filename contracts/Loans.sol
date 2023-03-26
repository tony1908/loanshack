// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract LoanContract {
    using SafeERC20 for IERC20;

    mapping(address => uint256) public loans;
    mapping(address => mapping(address => uint256)) public balances;
    mapping(address => mapping(address => uint256)) public allowances;

    event Deposit(address indexed token, address indexed borrower, uint256 amount);
    event Withdrawal(address indexed token, address indexed borrower, uint256 amount);
    event Loan(address indexed token, address indexed borrower, uint256 amount);
    event Repayment(address indexed token, address indexed borrower, uint256 amount);

    function deposit(address tokenAddress, uint256 amount) external {
        IERC20 token = IERC20(tokenAddress);
        token.safeTransferFrom(msg.sender, address(this), amount);
        balances[msg.sender][tokenAddress] += amount;
        allowances[msg.sender][tokenAddress] += amount;
        emit Deposit(tokenAddress, msg.sender, amount);
    }

    function withdraw(address tokenAddress, uint256 amount) external {
        IERC20 token = IERC20(tokenAddress);
        require(balances[msg.sender][tokenAddress] >= amount, "Insufficient balance");
        require(allowances[msg.sender][tokenAddress] >= amount, "Insufficient allowance");
        balances[msg.sender][tokenAddress] -= amount;
        allowances[msg.sender][tokenAddress] -= amount;
        token.safeTransfer(msg.sender, amount);
        emit Withdrawal(tokenAddress, msg.sender, amount);
    }

    function loan(address tokenAddress, uint256 amount) external {
        IERC20 token = IERC20(tokenAddress);
        require(balances[msg.sender][tokenAddress] >= amount, "Insufficient collateral");
        balances[msg.sender][tokenAddress] -= amount;
        loans[msg.sender] += amount;
        token.safeTransfer(msg.sender, amount);
        emit Loan(tokenAddress, msg.sender, amount);
    }

    function repay(address tokenAddress, uint256 amount) external {
        IERC20 token = IERC20(tokenAddress);
        require(loans[msg.sender] >= amount, "Insufficient loan amount");
        token.safeTransferFrom(msg.sender, address(this), amount);
        loans[msg.sender] -= amount;
        emit Repayment(tokenAddress, msg.sender, amount);
    }
}
