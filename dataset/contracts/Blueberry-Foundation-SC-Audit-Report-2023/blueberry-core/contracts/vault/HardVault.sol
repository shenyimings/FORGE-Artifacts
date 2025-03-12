// SPDX-License-Identifier: MIT
/*
██████╗ ██╗     ██╗   ██╗███████╗██████╗ ███████╗██████╗ ██████╗ ██╗   ██╗
██╔══██╗██║     ██║   ██║██╔════╝██╔══██╗██╔════╝██╔══██╗██╔══██╗╚██╗ ██╔╝
██████╔╝██║     ██║   ██║█████╗  ██████╔╝█████╗  ██████╔╝██████╔╝ ╚████╔╝
██╔══██╗██║     ██║   ██║██╔══╝  ██╔══██╗██╔══╝  ██╔══██╗██╔══██╗  ╚██╔╝
██████╔╝███████╗╚██████╔╝███████╗██████╔╝███████╗██║  ██║██║  ██║   ██║
╚═════╝ ╚══════╝ ╚═════╝ ╚══════╝╚═════╝ ╚══════╝╚═╝  ╚═╝╚═╝  ╚═╝   ╚═╝
*/

pragma solidity 0.8.16;

import "@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

import "../utils/BlueBerryErrors.sol" as Errors;
import "../utils/EnsureApprove.sol";
import "../interfaces/IProtocolConfig.sol";
import "../interfaces/IHardVault.sol";

/**
 * @author BlueberryProtocol
 * @title Hard Vault
 * @notice Hard Vault is a spot to lock LP tokens as collateral.
 * @dev HardVault is just holding LP tokens deposited by users.
 *      LP tokens should be listed by Blueberry team.
 *      HardVault is ERC1155 and Underlying LP tokens are identified by casted tokenId from token address
 * @dev HardVault is not on the road yet, need more research.
 */
contract HardVault is
    OwnableUpgradeable,
    ERC1155Upgradeable,
    ReentrancyGuardUpgradeable,
    EnsureApprove,
    IHardVault
{
    using SafeERC20Upgradeable for IERC20Upgradeable;

    /// @dev address of protocol config
    IProtocolConfig public config;

    event Deposited(
        address indexed account,
        uint256 amount,
        uint256 shareAmount
    );
    event Withdrawn(
        address indexed account,
        uint256 amount,
        uint256 shareAmount
    );

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(IProtocolConfig _config) external initializer {
        __ReentrancyGuard_init();
        __Ownable_init();
        __ERC1155_init("HardVault");

        if (address(_config) == address(0)) revert Errors.ZERO_ADDRESS();
        config = _config;
    }

    /// @dev Encode given underlying token address to tokenId
    function _encodeTokenId(address uToken) internal pure returns (uint) {
        return uint256(uint160(uToken));
    }

    /// @dev Decode given tokenId to underlyingToken address
    function _decodeTokenId(uint tokenId) internal pure returns (address) {
        return address(uint160(tokenId));
    }

    /// @notice Return the underlying ERC20 balance for the user.
    /// @param token token address to get balance of
    /// @param user user address to get balance of
    function balanceOfERC20(
        address token,
        address user
    ) external view override returns (uint256) {
        return balanceOf(user, _encodeTokenId(token));
    }

    /// @notice Return the underlying ERC-20 for the given ERC-1155 token id.
    /// @param tokenId token id (corresponds to token address for wrapped ERC20)
    /// @return token underlying token address of given tokenId
    function getUnderlyingToken(
        uint256 tokenId
    ) external pure override returns (address token) {
        token = _decodeTokenId(tokenId);
        if (_encodeTokenId(token) != tokenId)
            revert Errors.INVALID_TOKEN_ID(tokenId);
    }

    /**
     * @notice Deposit underlying assets on the vault and issue share token
     * @param amount Underlying token amount to deposit
     * @return shareAmount amount of vault share tokens minted
     */
    function deposit(
        address token,
        uint256 amount
    ) external override nonReentrant returns (uint256 shareAmount) {
        if (amount == 0) revert Errors.ZERO_AMOUNT();
        IERC20Upgradeable uToken = IERC20Upgradeable(token);
        uint256 uBalanceBefore = uToken.balanceOf(address(this));
        uToken.safeTransferFrom(msg.sender, address(this), amount);
        uint256 uBalanceAfter = uToken.balanceOf(address(this));

        shareAmount = uBalanceAfter - uBalanceBefore;
        _mint(msg.sender, uint256(uint160(token)), shareAmount, "");

        emit Deposited(msg.sender, amount, shareAmount);
    }

    /**
     * @notice Withdraw underlying assets from the vault
     * @param shareAmount Amount of vault share tokens to redeem
     * @return withdrawAmount Amount of underlying assets withdrawn
     */
    function withdraw(
        address token,
        uint256 shareAmount
    ) external override nonReentrant returns (uint256 withdrawAmount) {
        if (shareAmount == 0) revert Errors.ZERO_AMOUNT();
        IERC20Upgradeable uToken = IERC20Upgradeable(token);
        _burn(msg.sender, _encodeTokenId(token), shareAmount);

        // Cut withdraw fee if it is in withdrawVaultFee Window (2 months)
        _ensureApprove(
            address(uToken),
            address(config.feeManager()),
            shareAmount
        );
        withdrawAmount = config.feeManager().doCutVaultWithdrawFee(
            address(uToken),
            shareAmount
        );
        uToken.safeTransfer(msg.sender, withdrawAmount);

        emit Withdrawn(msg.sender, withdrawAmount, shareAmount);
    }
}
