// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/access/Ownable.sol";

import "../interfaces/ITreasuryPolicy.sol";

contract TreasuryPolicy is OwnableUpgradeSafe, ITreasuryPolicy {
    using SafeERC20 for IERC20;
    address public treasury;

    // fees
    uint256 public override redemption_fee; // 4 decimals of precision
    uint256 public constant REDEMPTION_FEE_MAX = 160; // 1.6%

    uint256 public override minting_fee; // 4 decimals of precision
    uint256 public constant MINTING_FEE_MAX = 80; // 0.8%

    // 1: NO TRADE
    // 2: TRADE SHARE <-> COLLATERAL
    // 3: ONLY COLLATERAL
    // 4: ONLY COLLATERAL -> BUY BACK SHARE WHEN REDEEM
    uint8 public override reserve_share_state;

    mapping(address => bool) public strategist;

    /* ========== EVENTS ============= */

    event StrategistStatusUpdated(address indexed account, bool status);
    event MintingFeeUpdated(uint256 fee);
    event RedemptionFeeUpdated(uint256 fee);
    event ReserveShareStateUpdated(uint256 _reserve_share_state);

    /* ========== MODIFIERS ========== */

    modifier onlyTreasuryOrOwner {
        require(msg.sender == treasury || msg.sender == owner(), "!treasury && !owner");
        _;
    }

    modifier onlyStrategist() {
        require(strategist[msg.sender] || msg.sender == treasury || msg.sender == owner(), "!strategist && !treasury && !owner");
        _;
    }

    /* ========== CONSTRUCTOR ========== */

    function initialize(
        address _treasury,
        uint256 _minting_fee,
        uint256 _redemption_fee
    ) external initializer {
        OwnableUpgradeSafe.__Ownable_init();

        treasury = _treasury;

        minting_fee = _minting_fee;
        redemption_fee = _redemption_fee;

        reserve_share_state = 1;
    }

    /* ========== RESTRICTED FUNCTIONS ========== */

    function setStrategistStatus(address _account, bool _status) external onlyOwner {
        strategist[_account] = _status;
        emit StrategistStatusUpdated(_account, _status);
    }

    function setMintingFee(uint256 _minting_fee) external override onlyStrategist {
        require(_minting_fee <= MINTING_FEE_MAX, ">MINTING_FEE_MAX");
        minting_fee = _minting_fee;
        emit MintingFeeUpdated(_minting_fee);
    }

    function setRedemptionFee(uint256 _redemption_fee) external override onlyStrategist {
        require(_redemption_fee <= REDEMPTION_FEE_MAX, ">REDEMPTION_FEE_MAX");
        redemption_fee = _redemption_fee;
        emit RedemptionFeeUpdated(_redemption_fee);
    }

    function setReserveShareState(uint8 _reserve_share_state) external onlyStrategist {
        reserve_share_state = _reserve_share_state;
        emit ReserveShareStateUpdated(_reserve_share_state);
    }

    /* ========== EMERGENCY ========== */

    function rescueStuckErc20(address _token) external onlyOwner {
        IERC20(_token).safeTransfer(owner(), IERC20(_token).balanceOf(address(this)));
    }
}
