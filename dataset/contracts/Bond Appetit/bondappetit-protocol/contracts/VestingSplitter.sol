// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/utils/EnumerableSet.sol";
import "./Vesting.sol";

contract VestingSplitter is Ownable {
    using SafeMath for uint256;
    using SafeERC20 for ERC20;
    using EnumerableSet for EnumerableSet.AddressSet;

    /**
     * @notice Vesting contract address.
     */
    address public vesting;

    /**
     * @notice Distributed tokens.
     */
    mapping(address => uint256) public totalSupply;

    /**
     * @dev Accounts balances.
     */
    mapping(address => mapping(address => uint256)) internal _balances;

    /**
     * @dev Accounts list.
     */
    EnumerableSet.AddressSet internal _accounts;

    /**
     * @dev Shares of account in split.
     */
    mapping(address => uint256) internal _share;

    /// @notice An event emitted when vesting contract address changed.
    event VestingChanged(address newVesting);

    /// @notice An event emitted when shares changed.
    event SharesChanged();

    /// @notice An event emitted when vesting period withdrawal.
    event VestingWithdraw(address vesting, uint256 periodId);

    /// @notice An event emitted when split a balance.
    event Split(address token);

    /// @notice An event emitted when withdrawal a token.
    event Withdraw(address token, address account, uint256 reward);

    /**
     * @param _vesting Vesting contract address.
     */
    constructor(address _vesting) public {
        vesting = _vesting;
    }

    /**
     * @notice Get accounts limit for split.
     * @return Max accounts for split.
     */
    function getMaxAccounts() public pure returns (uint256) {
        return 100;
    }

    /**
     * @notice Get accounts with share list.
     * @return Addresses of all accounts with share.
     */
    function getAccounts() public view returns (address[] memory) {
        address[] memory result = new address[](_accounts.length());

        for (uint256 i = 0; i < _accounts.length(); i++) {
            result[i] = _accounts.at(i);
        }

        return result;
    }

    /**
     * @notice Get balance of account.
     * @param token Target token.
     * @param account Target account.
     * @return Balance of account.
     */
    function balanceOf(address token, address account) public view returns (uint256) {
        return _balances[token][account];
    }

    /**
     * @notice Get share of account in split.
     * @param account Target account.
     * @return Share in split.
     */
    function shareOf(address account) public view returns (uint256) {
        return _share[account];
    }

    /**
     * @notice Change vesting contract address.
     * @param _vesting New vesting contract address.
     */
    function changeVesting(address _vesting) external onlyOwner {
        vesting = _vesting;
        emit VestingChanged(vesting);
    }

    /**
     * @notice Change shares of accounts in split.
     * @param accounts Accounts list.
     * @param shares Shares in split.
     */
    function changeShares(address[] memory accounts, uint256[] memory shares) external onlyOwner {
        require(accounts.length <= getMaxAccounts(), "VestingSplitter::changeShares: too many accounts");
        require(accounts.length == shares.length, "VestingSplitter::changeShares: shares function information arity mismatch");

        // Reverse loop because the length of the set changes inside the loop condition
        for (uint256 i = _accounts.length(); i > 0; i--) {
            address account = _accounts.at(0);
            _share[account] = 0;
            _accounts.remove(account);
        }

        uint256 sharesSum;
        for (uint256 i = 0; i < accounts.length; i++) {
            address account = accounts[i];
            require(!_accounts.contains(account), "VestingSplitter::changeShares: duplicate account");

            uint256 share = shares[i];
            require(share <= 100 && share > 0, "VestingSplitter::changeShares: invalid value of share");

            _share[account] = share;
            sharesSum = sharesSum.add(share);
            _accounts.add(account);
        }
        require(sharesSum == 100, "VestingSplitter::changeShares: invalid sum of shares");
        emit SharesChanged();
    }

    /**
     * @notice Withdraw reward from vesting contract.
     * @param periodId Target vesting period.
     */
    function vestingWithdraw(uint256 periodId) external {
        Vesting(vesting).withdraw(periodId);
        emit VestingWithdraw(vesting, periodId);
    }

    /**
     * @notice Split token to all accounts.
     * @param token Target token.
     */
    function split(address token) external {
        uint256 balance = ERC20(token).balanceOf(address(this)).sub(totalSupply[token]);
        require(balance > 0, "VestingSplitter::split: empty balance");

        for (uint256 i = 0; i < _accounts.length(); i++) {
            address account = _accounts.at(i);
            uint256 share = _share[account];
            uint256 reward = balance.mul(share).div(100);

            _balances[token][account] = _balances[token][account].add(reward);
            totalSupply[token] = totalSupply[token].add(reward);
        }
        emit Split(token);
    }

    /**
     * @notice Withdraw token balance to sender.
     * @param token Target token.
     */
    function withdraw(address token) external {
        uint256 reward = _balances[token][_msgSender()];
        _balances[token][_msgSender()] = 0;
        totalSupply[token] = totalSupply[token].sub(reward);
        ERC20(token).safeTransfer(_msgSender(), reward);
        emit Withdraw(token, _msgSender(), reward);
    }
}
