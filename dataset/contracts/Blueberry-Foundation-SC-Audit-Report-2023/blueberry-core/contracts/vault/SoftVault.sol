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

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

import "../utils/BlueBerryErrors.sol" as Errors;
import "../utils/EnsureApprove.sol";
import "../interfaces/IProtocolConfig.sol";
import "../interfaces/ISoftVault.sol";
import "../interfaces/compound/ICErc20.sol";

/**
 * @author BlueberryProtocol
 * @title Soft Vault
 * @notice Soft Vault is a spot where users lend and borrow tokens from/to Blueberry Money Market.
 * @dev SoftVault is communicating with bTokens to lend and borrow underlying tokens from/to Blueberry Money Market.
 *      Underlying tokens can be ERC20 tokens listed by Blueberry team, such as USDC, USDT, DAI, WETH, ...
 */
contract SoftVault is
    OwnableUpgradeable,
    ERC20Upgradeable,
    ReentrancyGuardUpgradeable,
    EnsureApprove,
    ISoftVault
{
    using SafeERC20Upgradeable for IERC20Upgradeable;

    /// @dev address of bToken for underlying token
    ICErc20 public bToken;
    /// @dev address of underlying token
    IERC20Upgradeable public uToken;
    /// @dev address of protocol config
    IProtocolConfig public config;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        IProtocolConfig _config,
        ICErc20 _bToken,
        string memory _name,
        string memory _symbol
    ) external initializer {
        __ReentrancyGuard_init();
        __Ownable_init();
        __ERC20_init(_name, _symbol);

        if (address(_bToken) == address(0) || address(_config) == address(0))
            revert Errors.ZERO_ADDRESS();

        IERC20Upgradeable _uToken = IERC20Upgradeable(_bToken.underlying());
        config = _config;
        bToken = _bToken;
        uToken = _uToken;
    }

    /// @dev Vault has same decimal as bToken, bToken has same decimal as underlyingToken
    function decimals() public view override returns (uint8) {
        return bToken.decimals();
    }

    /**
     * @notice Deposit underlying assets on Blueberry Money Market and issue share token
     * @param amount Underlying token amount to deposit
     * @return shareAmount same as bToken amount received
     */
    function deposit(
        uint256 amount
    ) external override nonReentrant returns (uint256 shareAmount) {
        if (amount == 0) revert Errors.ZERO_AMOUNT();
        uint256 uBalanceBefore = uToken.balanceOf(address(this));
        uToken.safeTransferFrom(msg.sender, address(this), amount);
        uint256 uBalanceAfter = uToken.balanceOf(address(this));

        uint256 cBalanceBefore = bToken.balanceOf(address(this));
        _ensureApprove(address(uToken), address(bToken), amount);
        if (bToken.mint(uBalanceAfter - uBalanceBefore) != 0)
            revert Errors.LEND_FAILED(amount);
        uint256 cBalanceAfter = bToken.balanceOf(address(this));

        shareAmount = cBalanceAfter - cBalanceBefore;
        _mint(msg.sender, shareAmount);

        emit Deposited(msg.sender, amount, shareAmount);
    }

    /**
     * @notice Withdraw underlying assets from Blueberry Money Market
     * @dev It cuts vault withdraw fee when you withdraw within the vault withdraw window (2 months)
     * @param shareAmount Amount of bTokens to redeem
     * @return withdrawAmount Amount of underlying assets withdrawn
     */
    function withdraw(
        uint256 shareAmount
    ) external override nonReentrant returns (uint256 withdrawAmount) {
        if (shareAmount == 0) revert Errors.ZERO_AMOUNT();

        _burn(msg.sender, shareAmount);

        uint256 uBalanceBefore = uToken.balanceOf(address(this));
        if (bToken.redeem(shareAmount) != 0)
            revert Errors.REDEEM_FAILED(shareAmount);
        uint256 uBalanceAfter = uToken.balanceOf(address(this));

        withdrawAmount = uBalanceAfter - uBalanceBefore;
        _ensureApprove(
            address(uToken),
            address(config.feeManager()),
            withdrawAmount
        );
        withdrawAmount = config.feeManager().doCutVaultWithdrawFee(
            address(uToken),
            withdrawAmount
        );
        uToken.safeTransfer(msg.sender, withdrawAmount);

        emit Withdrawn(msg.sender, withdrawAmount, shareAmount);
    }
}
