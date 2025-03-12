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
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/IERC20MetadataUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

import "../utils/BlueBerryErrors.sol" as Errors;
import "../utils/EnsureApprove.sol";
import "../libraries/BBMath.sol";
import "../interfaces/IWIchiFarm.sol";
import "../interfaces/IERC20Wrapper.sol";
import "../interfaces/ichi/IIchiV2.sol";
import "../interfaces/ichi/IIchiFarm.sol";

/**
 * @title WIchiFarm
 * @author BlueberryProtocol
 * @notice Wrapped IchiFarm is the wrapper of ICHI MasterChef
 * @dev Leveraged ICHI Lp Tokens will be wrapped here and be held in BlueberryBank.
 *      At the same time, Underlying LPs will be deposited to ICHI farming pools and generate yields
 *      LP Tokens are identified by tokenIds encoded from lp token address and accPerShare of deposited time
 */
contract WIchiFarm is
    ERC1155Upgradeable,
    ReentrancyGuardUpgradeable,
    EnsureApprove,
    IERC20Wrapper,
    IWIchiFarm
{
    using BBMath for uint256;
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using SafeERC20Upgradeable for IIchiV2;

    /// @dev address of legacy ICHI token
    IERC20Upgradeable public ICHIv1;
    /// @dev address of ICHI v2
    IIchiV2 public ICHI;
    /// @dev address of ICHI farming contract
    IIchiFarm public ichiFarm;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address ichi_,
        address ichiV1,
        address ichiFarm_
    ) external initializer {
        if (
            address(ichi_) == address(0) ||
            address(ichiV1) == address(0) ||
            address(ichiFarm_) == address(0)
        ) revert Errors.ZERO_ADDRESS();
        __ReentrancyGuard_init();
        __ERC1155_init("WIchiFarm");
        ICHI = IIchiV2(ichi_);
        ICHIv1 = IERC20Upgradeable(ichiV1);
        ichiFarm = IIchiFarm(ichiFarm_);
    }

    /// @notice Encode pid, ichiPerShare to ERC1155 token id
    /// @param pid Pool id (16-bit)
    /// @param ichiPerShare Ichi amount per share, multiplied by 1e18 (240-bit)
    function encodeId(
        uint256 pid,
        uint256 ichiPerShare
    ) public pure returns (uint256 id) {
        if (pid >= (1 << 16)) revert Errors.BAD_PID(pid);
        if (ichiPerShare >= (1 << 240))
            revert Errors.BAD_REWARD_PER_SHARE(ichiPerShare);
        return (pid << 240) | ichiPerShare;
    }

    /// @notice Decode ERC1155 token id to pid, ichiPerShare
    /// @param id Token id
    function decodeId(
        uint256 id
    ) public pure returns (uint256 pid, uint256 ichiPerShare) {
        pid = id >> 240; // First 16 bits
        ichiPerShare = id & ((1 << 240) - 1); // Last 240 bits
    }

    /// @notice Return the underlying ERC-20 for the given ERC-1155 token id.
    /// @param id Token id
    function getUnderlyingToken(
        uint256 id
    ) external view override returns (address) {
        (uint256 pid, ) = decodeId(id);
        return ichiFarm.lpToken(pid);
    }

    /// @notice Return pending rewards from the farming pool
    /// @param tokenId Token Id
    /// @param amount amount of share
    function pendingRewards(
        uint256 tokenId,
        uint amount
    )
        public
        view
        override
        returns (address[] memory tokens, uint256[] memory rewards)
    {
        (uint256 pid, uint256 stIchiPerShare) = decodeId(tokenId);
        uint256 lpDecimals = IERC20MetadataUpgradeable(ichiFarm.lpToken(pid))
            .decimals();
        (uint256 enIchiPerShare, , ) = ichiFarm.poolInfo(pid);
        uint256 stIchi = (stIchiPerShare * amount).divCeil(10 ** lpDecimals);
        uint256 enIchi = (enIchiPerShare * amount) / (10 ** lpDecimals);
        uint256 ichiRewards = enIchi > stIchi ? enIchi - stIchi : 0;
        // Convert rewards to ICHI(v2) => ICHI v1 decimal: 9, ICHI v2 Decimal: 18
        ichiRewards *= 1e9;

        tokens = new address[](1);
        rewards = new uint256[](1);
        tokens[0] = address(ICHI);
        rewards[0] = ichiRewards;
    }

    /// @notice Mint ERC1155 token for the given pool id.
    /// @param pid Pool id
    /// @param amount Token amount to wrap
    /// @return The token id that got minted.
    function mint(
        uint256 pid,
        uint256 amount
    ) external nonReentrant returns (uint256) {
        address lpToken = ichiFarm.lpToken(pid);
        IERC20Upgradeable(lpToken).safeTransferFrom(
            msg.sender,
            address(this),
            amount
        );

        _ensureApprove(lpToken, address(ichiFarm), amount);
        ichiFarm.deposit(pid, amount, address(this));
        (uint256 ichiPerShare, , ) = ichiFarm.poolInfo(pid);
        uint256 id = encodeId(pid, ichiPerShare);
        _mint(msg.sender, id, amount, "");
        return id;
    }

    /// @notice Burn ERC1155 token to redeem LP ERC20 token back plus ICHI rewards.
    /// @param id Token id
    /// @param amount Token amount to burn
    /// @return The pool id that that you will receive LP token back.
    function burn(
        uint256 id,
        uint256 amount
    ) external nonReentrant returns (uint256) {
        if (amount == type(uint256).max) {
            amount = balanceOf(msg.sender, id);
        }
        (uint256 pid, ) = decodeId(id);
        _burn(msg.sender, id, amount);

        uint256 ichiRewards = ichiFarm.pendingIchi(pid, address(this));
        ichiFarm.harvest(pid, address(this));
        ichiFarm.withdraw(pid, amount, address(this));

        // Convert Legacy ICHI to ICHI v2
        if (ichiRewards > 0) {
            _ensureApprove(address(ICHIv1), address(ICHI), ichiRewards);
            ICHI.convertToV2(ichiRewards);
        }

        // Transfer LP Tokens
        address lpToken = ichiFarm.lpToken(pid);
        IERC20Upgradeable(lpToken).safeTransfer(msg.sender, amount);

        // Transfer Reward Tokens
        (, uint256[] memory rewards) = pendingRewards(id, amount);

        if (rewards[0] > 0) {
            ICHI.safeTransfer(msg.sender, rewards[0]);
        }
        return pid;
    }
}
