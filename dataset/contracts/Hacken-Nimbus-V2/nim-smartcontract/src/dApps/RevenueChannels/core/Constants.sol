pragma solidity 0.5.17;

import "../interfaces/IWethERC20.sol";


contract Constants {

    uint256 internal constant WEI_PRECISION = 10**18;
    uint256 internal constant WEI_PERCENT_PRECISION = 10**20;

    uint256 internal constant DAYS_IN_A_YEAR = 365;
    uint256 internal constant ONE_MONTH = 2628000; // approx. seconds in a month

    string internal constant UserRewardsID = "UserRewards";
    string internal constant LoanDepositValueID = "LoanDepositValue";

    IWethERC20 public constant wethToken = IWethERC20(0x0BCd83DF58a1BfD25b1347F9c9dA1b7118b648a6);
    address public constant nbuTokenAddress = 0xEB58343b36C7528F23CAAe63a150240241310049;
}
