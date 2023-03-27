// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IConnext} from "@connext/interfaces/core/IConnext.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IXReceiver} from "@connext/interfaces/core/IXReceiver.sol";

contract InterChangeLoan is IXReceiver {
    string public los;

    using SafeERC20 for IERC20;

    // The Connext contract on this domain
    IConnext public immutable connext;

    // The token to be paid on this domain
    IERC20 public immutable token;

    // Slippage (in BPS) for the transfer set to 100% for this example
    uint256 public immutable slippage = 10000;

    mapping(address => uint256) public loans;
    mapping(address => mapping(address => uint256)) public balances;
    mapping(address => mapping(address => uint256)) public allowances;

    event Deposit(address indexed token, address indexed borrower, uint256 amount);
    event Withdrawal(address indexed token, address indexed borrower, uint256 amount);
    event Loan(address indexed token, address indexed borrower, uint256 amount);
    event Repayment(address indexed token, address indexed borrower, uint256 amount);

    constructor(address _connext, address _token) {
        connext = IConnext(_connext);
        token = IERC20(_token);
    }


    function deposit(address tokenAddress, uint256 amount) external {
        //IERC20 token = IERC20(tokenAddress);
        token.safeTransferFrom(msg.sender, address(this), amount);
        balances[msg.sender][tokenAddress] += amount;
        allowances[msg.sender][tokenAddress] += amount;
        emit Deposit(tokenAddress, msg.sender, amount);
    }

    function crossDeposit (
        address target,
        uint32 destinationDomain,
        uint256 amount,
        uint256 relayerFee
    ) external payable {
        require(
            token.allowance(msg.sender, address(this)) >= amount,
            "User must approve amount"
        );

        // User sends funds to this contract
        token.transferFrom(msg.sender, address(this), amount);

        // This contract approves transfer to Connext
        token.approve(address(connext), amount);

        // Encode calldata for the target contract call
        bytes memory callData = abi.encode(msg.sender);

        connext.xcall{value: relayerFee}(
            destinationDomain, // _destination: Domain ID of the destination chain
            target,            // _to: address of the target contract
            address(token),    // _asset: address of the token contract
            msg.sender,        // _delegate: address that can revert or forceLocal on destination
            amount,            // _amount: amount of tokens to transfer
            slippage,          // _slippage: max slippage the user will accept in BPS (e.g. 300 = 3%)
            callData           // _callData: the encoded calldata to send
        );
    }

    function xReceive(
        bytes32 _transferId,
        uint256 _amount,
        address _asset,
        address _originSender,
        uint32 _origin,
        bytes memory _callData
    ) external returns (bytes memory) {
        // Check for the right token
        require(
            _asset == address(token),
            "Wrong asset received"
        );
        // Enforce a cost to update the greeting
        require(
            _amount > 0,
            "Must pay at least 1 wei"
        );

        // Unpack the _callData
        string memory newAddress = abi.decode(_callData, (string));


        //loans[msg.sender] += _amount;
        _updateLoan(newAddress);
    }

    function _updateLoan(string memory newL) internal {
        los = newL;
    }

    function withdraw(address tokenAddress, uint256 amount) external {
        //IERC20 token = IERC20(tokenAddress);
        require(balances[msg.sender][tokenAddress] >= amount, "Insufficient balance");
        require(allowances[msg.sender][tokenAddress] >= amount, "Insufficient allowance");
        balances[msg.sender][tokenAddress] -= amount;
        allowances[msg.sender][tokenAddress] -= amount;
        token.safeTransfer(msg.sender, amount);
        emit Withdrawal(tokenAddress, msg.sender, amount);
    }

    function loan(address tokenAddress, uint256 amount) external {
        //IERC20 token = IERC20(tokenAddress);
        require(balances[msg.sender][tokenAddress] >= amount, "Insufficient collateral");
        balances[msg.sender][tokenAddress] -= amount;
        loans[msg.sender] += amount;
        token.safeTransfer(msg.sender, amount);
        emit Loan(tokenAddress, msg.sender, amount);
    }

    function repay(address tokenAddress, uint256 amount) external {
        //IERC20 token = IERC20(tokenAddress);
        require(loans[msg.sender] >= amount, "Insufficient loan amount");
        token.safeTransferFrom(msg.sender, address(this), amount);
        loans[msg.sender] -= amount;
        emit Repayment(tokenAddress, msg.sender, amount);
    }
}