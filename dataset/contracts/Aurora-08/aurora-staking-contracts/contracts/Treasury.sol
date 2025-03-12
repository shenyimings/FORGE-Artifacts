// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import "./ITreasury.sol";
import "./AdminControlled.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";

contract Treasury is ITreasury, AdminControlled {
    using SafeERC20Upgradeable for IERC20Upgradeable;
    bytes32 public constant TREASURY_MANAGER_ROLE =
        keccak256("TREASURY_MANAGER_ROLE");
    mapping(address => bool) public isSupportedToken;
    //events
    event TokenAdded(
        address indexed token,
        address indexed addedBy,
        uint256 timestamp
    );
    event TokenRemoved(
        address indexed token,
        address indexed addedBy,
        uint256 timestamp
    );

    /// @notice initializes ownable Treasury with list of managers and supported tokens
    /// @param _supportedTokens list of supported tokens
    function initialize(address[] memory _supportedTokens, uint256 _flags)
        external
        initializer
    {
        for (uint256 i = 0; i < _supportedTokens.length; i++) {
            require(_supportedTokens[i] != address(0), "INVALID_TOKEN_ADDRESS");
            isSupportedToken[_supportedTokens[i]] = true;
        }
        __AdminControlled_init(_flags);
        _grantRole(TREASURY_MANAGER_ROLE, msg.sender);
    }

    /// @notice transfers token amount from Treasury balance to user.
    /// @dev Used by jet staking contracts
    /// @param _user user to transfer tokens to
    /// @param _token token to transfer to user
    /// @param _amount token to transfer to user
    function payRewards(
        address _user,
        address _token,
        uint256 _amount
    ) external pausable(1) onlyRole(DEFAULT_ADMIN_ROLE) {
        require(isSupportedToken[_token], "TOKEN_IS_NOT_SUPPORTED");
        IERC20Upgradeable(_token).safeTransfer(_user, _amount);
    }

    /// @notice adds token as a supproted rewards token by Treasury
    /// supported tokens means any future stream token should be
    /// whitelisted here
    /// @param _token stream ERC20 token address
    function addSupportedToken(address _token)
        external
        onlyRole(TREASURY_MANAGER_ROLE)
    {
        require(!isSupportedToken[_token], "TOKEN_ALREADY_EXISTS");
        isSupportedToken[_token] = true;
        emit TokenAdded(_token, msg.sender, block.timestamp);
    }

    /// @notice removed token as a supproted rewards token by Treasury
    /// @param _token stream ERC20 token address
    function removeSupportedToken(address _token)
        external
        onlyRole(TREASURY_MANAGER_ROLE)
    {
        require(isSupportedToken[_token], "TOKEN_DOES_NOT_EXIST");
        isSupportedToken[_token] = false;
        emit TokenRemoved(_token, msg.sender, block.timestamp);
    }
}
