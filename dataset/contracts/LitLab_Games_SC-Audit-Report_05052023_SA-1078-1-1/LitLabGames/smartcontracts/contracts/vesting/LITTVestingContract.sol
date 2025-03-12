// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../utils/Ownable.sol";

/// @title LITTVestingContract
/// @notice Vesting contract for LitlabGames token
contract LITTVestingContract is Ownable {
    using SafeERC20 for IERC20;

    enum VestingType {
        NEW_GAMES,
        MARKETING,
        LIQUID_RESERVES,
        AIRDROPS,
        INGAME_REWARDS,
        FARMING
    }

    uint256 constant public NEW_GAMES_AMOUNT = 555000000 * 10 ** 18;
    uint256 constant public MARKETING_AMOUNT = 150000000 * 10 ** 18;
    uint256 constant public LIQUID_RESERVES_AMOUNT = 210000000 * 10 ** 18;
    uint256 constant public AIRDROPS_AMOUNT = 30000000 * 10 ** 18;
    uint256 constant public INGAME_REWARDS_AMOUNT = 325000000 * 10 ** 18;
    uint256 constant public FARMING_AMOUNT = 420000000 * 10 ** 18;

    uint8 constant public NEW_GAMES_CLIFF = 9;
    uint8 constant public LIQUID_RESERVES_CLIFF = 3;

    uint8 constant public AIRDROPS_UNLOCK_TGE = 15;

    uint8 constant public NEW_GAMES_LINEAR_MONTHS = 54;
    uint8 constant public MARKETING_LINEAR_MONTHS = 18;
    uint8 constant public LIQUID_RESERVES_LINEAR_MONTHS = 24;
    uint8 constant public AIRDROPS_LINEAR_MONTHS = 12;

    struct VestingData {
        uint256 _amount;
        uint256 _amountTGE;
        uint256 _TGEPercentage;
        uint256 _months;
        uint256 _cliffMonths;
    }

    mapping(VestingType => VestingData) private vestingData;
    mapping(VestingType => uint256) public withdrawnBalances;
    mapping(VestingType => uint256) public lastWithdraw;

    address public immutable token;
    address public wallet;
    uint256 public listing_date;
    
    event ListingDated(uint256 indexed _listingDate);
    event WalletChanged(address indexed _wallet);
    event TokenWithdrawn(address indexed _wallet, uint256 _amount);
    event EmergencyWithdrawn();

    /// @notice Set the token address, the withdraw wallet and the vesting amounts
    constructor(address _token, address _wallet) {
        require(_token != address(0), "ZeroAddress");
        require(_wallet != address(0), "ZeroAddress");

        token = _token;
        wallet = _wallet;

        vestingData[VestingType.NEW_GAMES] = VestingData({
            _amount: NEW_GAMES_AMOUNT,
            _amountTGE: 0,
            _months: NEW_GAMES_LINEAR_MONTHS,
            _cliffMonths: NEW_GAMES_CLIFF,
            _TGEPercentage: 0
        });
        vestingData[VestingType.MARKETING] = VestingData({
            _amount: MARKETING_AMOUNT,
            _amountTGE: 0,
            _months: MARKETING_LINEAR_MONTHS,
            _cliffMonths: 0,
            _TGEPercentage: 0
        });
        vestingData[VestingType.LIQUID_RESERVES] = VestingData({
            _amount: LIQUID_RESERVES_AMOUNT,
            _amountTGE: 0,
            _months: LIQUID_RESERVES_LINEAR_MONTHS,
            _cliffMonths: LIQUID_RESERVES_CLIFF,
            _TGEPercentage: 0
        });
        vestingData[VestingType.AIRDROPS] = VestingData({
            _amount: AIRDROPS_AMOUNT,
            _amountTGE: AIRDROPS_AMOUNT * AIRDROPS_UNLOCK_TGE / 100,
            _months: AIRDROPS_LINEAR_MONTHS,
            _cliffMonths: 0,
            _TGEPercentage: AIRDROPS_UNLOCK_TGE
        });

        emit WalletChanged(_wallet);
    }

    /// @notice Set TGE date (listing date)
    function setListingDate(uint256 _listingDate) external onlyOwner {
        require(_listingDate >= block.timestamp, "NoPastDate");
        require(listing_date == 0 || block.timestamp < listing_date, "CannotChangeAfterListing");
        listing_date = _listingDate;

        emit ListingDated(_listingDate);
    }

    /// @notice Change the Company wallet
    function changeWallet(address _wallet) external onlyOwner {
        require(_wallet != address(0), "ZeroAddress");
        wallet = _wallet;

        emit WalletChanged(_wallet);
    }

    /// @notice Get vesting data
    function getVestingData(uint8 _vestingType) external view returns (
        uint256 amount, 
        uint256 TGEPercentage, 
        uint256 months, 
        uint256 cliffMonths, 
        uint256 withdrawn
    ) {
        VestingData memory data = vestingData[VestingType(_vestingType)];
        amount = data._amount;
        TGEPercentage = data._TGEPercentage;
        months = data._months;
        cliffMonths = data._cliffMonths;
        withdrawn = withdrawnBalances[VestingType(_vestingType)];
    }

    /// @notice Withdraw from New Games pool (not vested)
    function withdrawNewGames() external {
        // New Games 9 months cliff, linearly over 54 months
        _executeVesting(VestingType.NEW_GAMES);
    }

    /// @notice Withdraw from Marketing pool (vested)
    function withdrawMarketing() external {
        // Marketing 5% at TGE, linearly over 18 months
        _executeVesting(VestingType.MARKETING);
    }

    /// @notice Withdraw from Liquid reserves pool (vested)
    function withdrawLiquidReserves() external {
        // Liquid ReservesVesting linearly over 24 months
        _executeVesting(VestingType.LIQUID_RESERVES);
    }

    /// @notice Withdraw from Airdrops pool (vested)
    function withdrawAirdrops() external {
        // Airdrops	10% at TGE, linearly over 12 months
        _executeVesting(VestingType.AIRDROPS);
    }

    /// @notice Withdraw from InGame pool (not vested)
    function withdrawInGameRewards(uint256 _amount) external {
        // Free withdraw
        require(withdrawnBalances[VestingType.INGAME_REWARDS] + _amount <= INGAME_REWARDS_AMOUNT, "CantWithdrawMore");
        _sendTokens(wallet, VestingType.INGAME_REWARDS, _amount, false);
    }

    /// @notice Withdraw from Farming pool (not vested)
    function withdrawFarming(uint256 _amount) external {
        // Free withdraw
        require(withdrawnBalances[VestingType.FARMING] + _amount <= FARMING_AMOUNT, "CantWithdrawMore");
        _sendTokens(wallet, VestingType.FARMING, _amount, false);
    }

    /// @notice Get the tokens in the contract
    function getTokensInVesting() external view returns(uint256) {
        return IERC20(token).balanceOf(address(this));
    }

    /// @notice If there's any problem, contract owner can withdraw all funds
    function emergencyWithdraw() external onlyOwner {
        uint256 balance = IERC20(token).balanceOf(address(this));
        IERC20(token).safeTransfer(msg.sender, balance);

        emit EmergencyWithdrawn();
    }

    /// @notice Internal function to calculate the amount of tokens user can get according the vesting
    function _executeVesting(VestingType _vestingType) internal {
        VestingData storage data = vestingData[_vestingType];
        uint256 amount = data._amount;
        uint256 amountTGE = data._amountTGE;
        require(block.timestamp >= listing_date + (data._cliffMonths * 30 days), "TooEarly");
        require(withdrawnBalances[_vestingType] < amount, "MaxBalance");

        if ((data._TGEPercentage > 0) && (withdrawnBalances[_vestingType] == 0)) {
            _sendTokens(wallet, _vestingType, data._amountTGE, true);
        } else {
            uint256 start = listing_date + (data._cliffMonths * 30 days);
            uint256 end = start + (data._months * 30 days);
            uint256 amountToWithdraw;
            if (block.timestamp < end) {
                uint256 from = lastWithdraw[_vestingType] == 0 ? start : lastWithdraw[_vestingType];
                uint256 to = block.timestamp;
                uint256 tokensPerSecond = (amount - amountTGE) / (end - start);
                amountToWithdraw = (to - from) * tokensPerSecond;
            } else {
                // This is the last time users can withdraw, so he withdraws all their remaining tokens
                amountToWithdraw = amount - withdrawnBalances[_vestingType];
            }
            _sendTokens(wallet, _vestingType, amountToWithdraw, false);
        }
    }

    function _sendTokens(address _wallet, VestingType _vestingType, uint256 _amount, bool _tge) internal {
        withdrawnBalances[_vestingType] += _amount;
        if (!_tge) lastWithdraw[_vestingType] = block.timestamp;
        IERC20(token).safeTransfer(_wallet, _amount);

        emit TokenWithdrawn(_wallet, _amount);
    }
}
