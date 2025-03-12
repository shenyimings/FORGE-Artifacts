/*
 * SPDX-License-Identitifer:    GPL-3.0-or-later
 */

pragma solidity 0.4.24;

import "@aragon/os/contracts/apps/AragonApp.sol";
import "@aragon/os/contracts/common/IForwarder.sol";
import "@aragon/os/contracts/common/IsContract.sol";
import "@aragon/os/contracts/lib/math/SafeMath.sol";
import "@aragon/os/contracts/lib/token/ERC20.sol";

import "@aragonone/voting-connectors-contract-utils/contracts/Checkpointing.sol";
import "@aragonone/voting-connectors-contract-utils/contracts/ERC20ViewOnly.sol";
import "@aragonone/voting-connectors-contract-utils/contracts/interfaces/IERC20WithCheckpointing.sol";
import "@aragonone/voting-connectors-contract-utils/contracts/interfaces/IERC20WithDecimals.sol";


/**
 * @title TokenWrapper
 * @notice Wrapper around a normal ERC20 token that provides a "view-only" checkpointed ERC20
 *         implementation for use with Voting apps.
 * @dev Inspired by:
 *   - MiniMe token
 *   - https://github.com/MyBitFoundation/MyBit-DAO.tech/blob/master/apps/MyTokens/contracts/MyTokens.sol
 */
contract TokenWrapper is IERC20WithCheckpointing, IForwarder, IsContract, ERC20ViewOnly, AragonApp {
    using SafeMath for uint256;
    using SafeERC20 for ERC20;
    using Checkpointing for Checkpointing.History;

    string private constant ERROR_TOKEN_NOT_CONTRACT = "TW_TOKEN_NOT_CONTRACT";
    string private constant ERROR_DEPOSIT_AMOUNT_ZERO = "TW_DEPOSIT_AMOUNT_ZERO";
    string private constant ERROR_TOKEN_TRANSFER_FROM_FAILED = "TW_TOKEN_TRANSFER_FROM_FAILED";
    string private constant ERROR_WITHDRAW_AMOUNT_ZERO = "TW_WITHDRAW_AMOUNT_ZERO";
    string private constant ERROR_INVALID_WITHDRAW_AMOUNT = "TW_INVALID_WITHDRAW_AMOUNT";
    string private constant ERROR_TOKEN_TRANSFER_FAILED = "TW_TOKEN_TRANSFER_FAILED";
    string private constant ERROR_CAN_NOT_FORWARD = "TW_CAN_NOT_FORWARD";

    ERC20 public depositedToken;
    string public name;
    string public symbol;

    // Checkpointed balances of the deposited token by block number
    mapping (address => Checkpointing.History) internal balancesHistory;

    // Checkpointed total supply of the deposited token
    Checkpointing.History internal totalSupplyHistory;

    event Deposit(address indexed entity, uint256 amount);
    event Withdrawal(address indexed entity, uint256 amount);

    /**
     * @notice Create a new "wrapped" checkpointed token that is convertible from a normal ERC20 token
     * @param _depositedToken The ERC20 token to be wrapped
     * @param _name The wrapped token's name
     * @param _symbol The wrapped token's symbol
     */
    function initialize(ERC20 _depositedToken, string _name, string _symbol) external onlyInit {
        initialized();

        require(isContract(_depositedToken), ERROR_TOKEN_NOT_CONTRACT);

        depositedToken = _depositedToken;
        name = _name;
        symbol = _symbol;
    }

    /**
     * @notice Wrap `@tokenAmount(self.depositedToken(): address, _amount)`
     * @param _amount Amount to wrap
     */
    function deposit(uint256 _amount) external isInitialized {
        require(_amount > 0, ERROR_DEPOSIT_AMOUNT_ZERO);

        // Fetch the outside ERC20 tokens
        require(depositedToken.safeTransferFrom(msg.sender, address(this), _amount), ERROR_TOKEN_TRANSFER_FROM_FAILED);

        // Then increase our wrapped token accounting
        uint256 currentBalance = balanceOf(msg.sender);
        uint256 newBalance = currentBalance.add(_amount);

        uint256 currentTotalSupply = totalSupply();
        uint256 newTotalSupply = currentTotalSupply.add(_amount);

        uint256 currentBlock = getBlockNumber();
        balancesHistory[msg.sender].addCheckpoint(currentBlock, newBalance);
        totalSupplyHistory.addCheckpoint(currentBlock, newTotalSupply);

        emit Deposit(msg.sender, _amount);
    }

    /**
     * @notice Unwrap `@tokenAmount(self.depositedToken(): address, _amount)`
     * @param _amount Amount to unwrap
     */
    function withdraw(uint256 _amount) external isInitialized {
        require(_amount > 0, ERROR_WITHDRAW_AMOUNT_ZERO);

        uint256 currentBalance = balanceOf(msg.sender);
        require(_amount <= currentBalance, ERROR_INVALID_WITHDRAW_AMOUNT);

        // Decrease our wrapped token accounting
        uint256 newBalance = currentBalance.sub(_amount);

        uint256 currentTotalSupply = totalSupply();
        uint256 newTotalSupply = currentTotalSupply.sub(_amount);

        uint256 currentBlock = getBlockNumber();
        balancesHistory[msg.sender].addCheckpoint(currentBlock, newBalance);
        totalSupplyHistory.addCheckpoint(currentBlock, newTotalSupply);

        // Then return ERC20 tokens
        require(depositedToken.safeTransfer(msg.sender, _amount), ERROR_TOKEN_TRANSFER_FAILED);

        emit Withdrawal(msg.sender, _amount);
    }

    // ERC20 fns - note that this token is a non-transferrable "view-only" implementation.
    // Users should only be changing balances by depositing and withdrawing tokens.
    // These functions do **NOT** revert if the app is uninitialized to stay compatible with normal ERC20s.

    function balanceOf(address _owner) public view returns (uint256) {
        return _balanceOfAt(_owner, getBlockNumber());
    }

    function decimals() public view returns (uint8) {
        // Decimals is optional; proxy to outside token
        return IERC20WithDecimals(depositedToken).decimals();
    }

    function totalSupply() public view returns (uint256) {
        return _totalSupplyAt(getBlockNumber());
    }

    // Checkpointed fns
    // These functions do **NOT** revert if the app is uninitialized to stay compatible with normal ERC20s.

    function balanceOfAt(address _owner, uint256 _blockNumber) public view returns (uint256) {
        return _balanceOfAt(_owner, _blockNumber);
    }

    function totalSupplyAt(uint256 _blockNumber) public view returns (uint256) {
        return _totalSupplyAt(_blockNumber);
    }

    // Forwarding fns

    /**
    * @notice Tells whether the TokenWrapper app is a forwarder or not
    * @dev IForwarder interface conformance
    * @return Always true
    */
    function isForwarder() public pure returns (bool) {
        return true;
    }

    /**
     * @notice Execute desired action as a token holder
     * @dev IForwarder interface conformance. Forwards any token holder action.
     * @param _evmScript Script being executed
     */
    function forward(bytes _evmScript) public {
        require(canForward(msg.sender, _evmScript), ERROR_CAN_NOT_FORWARD);
        bytes memory input = new bytes(0);

        // Add the wrapped token to the blacklist to disallow a token holder from interacting with
        // the token on this contract's behalf (e.g. maliciously causing a transfer).
        address[] memory blacklist = new address[](1);
        blacklist[0] = address(depositedToken);

        runScript(_evmScript, input, blacklist);
    }

    /**
    * @notice Tells whether `_sender` can forward actions or not
    * @dev IForwarder interface conformance
    * @param _sender Address of the account intending to forward an action
    * @return True if the given address can forward actions, false otherwise
    */
    function canForward(address _sender, bytes) public view returns (bool) {
        return hasInitialized() && balanceOf(_sender) > 0;
    }

    // Internal fns

    function _balanceOfAt(address _owner, uint256 _blockNumber) internal view returns (uint256) {
        return balancesHistory[_owner].getValueAt(_blockNumber);
    }

    function _totalSupplyAt(uint256 _blockNumber) internal view returns (uint256) {
        return totalSupplyHistory.getValueAt(_blockNumber);
    }
}
