// SPDX-License-Identifier: MIT
pragma solidity >=0.7.2;
import "@chainlink/contracts/src/v0.6/interfaces/AggregatorV3Interface.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

enum HegicOptionType {Invalid, Put, Call}
enum State {Inactive, Active, Exercised, Expired}

struct HegicOption {
    State state;
    address payable holder;
    uint256 strike;
    uint256 amount;
    uint256 lockedAmount;
    uint256 premium;
    uint256 expiration;
    HegicOptionType optionType;
}

interface IHegicOptions {
    event Create(
        uint256 indexed id,
        address indexed account,
        uint256 settlementFee,
        uint256 totalFee
    );

    event Exercise(uint256 indexed id, uint256 profit);
    event Expire(uint256 indexed id, uint256 premium);

    function options(uint256)
        external
        view
        returns (
            State state,
            address payable holder,
            uint256 strike,
            uint256 amount,
            uint256 lockedAmount,
            uint256 premium,
            uint256 expiration,
            HegicOptionType optionType
        );

    function create(
        uint256 period,
        uint256 amount,
        uint256 strike,
        HegicOptionType optionType
    ) external payable returns (uint256 optionID);

    function exercise(uint256 optionID) external;

    function priceProvider() external view returns (address);
}

interface IHegicETHOptions is IHegicOptions {
    function fees(
        uint256 period,
        uint256 amount,
        uint256 strike,
        HegicOptionType optionType
    )
        external
        view
        returns (
            uint256 total,
            uint256 settlementFee,
            uint256 strikeFee,
            uint256 periodFee
        );
}

interface IHegicBTCOptions is IHegicOptions {
    function fees(
        uint256 period,
        uint256 amount,
        uint256 strike,
        HegicOptionType optionType
    )
        external
        view
        returns (
            uint256 total,
            uint256 totalETH,
            uint256 settlementFee,
            uint256 strikeFee,
            uint256 periodFee
        );
}

interface IHegicRewards {
  function hegic() external view returns (IERC20);
  function hegicOptions() external view returns (IHegicOptions);
  function rewardsRate() external view returns (uint256);
  function rewardedOptions(uint optionId) external view returns(bool);
  function getReward(uint optionId) external;
}
