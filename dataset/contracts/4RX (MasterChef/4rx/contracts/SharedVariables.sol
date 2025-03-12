// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./InterestCalculator.sol";
import "./Events.sol";
import "./PercentageCalculator.sol";
import "./utils/Utils.sol";
import "./Constants.sol";
import "./StatsVars.sol";


contract SharedVariables is Constants, StatsVars, Events, PercentageCalculator, InterestCalculator, Utils {
    IERC20 public fourRXToken;
    uint public fourRXTokenDecimals;

    address public devAddress = 0x64B8cb4C04Ba902010856d913B4e5DF940748Bf2; // Dummy address replace it for prod/dev

    struct Stake {
        uint8 id;
        bool active;
        bool optInInsured; // Is insured ???

        uint32 holdFrom; // Timestamp from which hold should be counted
        uint32 interestCountFrom; // TimeStamp from which interest should be counted, from the beginning
        uint32 lastWithdrawalAt; // date time of last withdrawals so we don't allow more then 3% a day

        uint deposit; // Initial Deposit
        uint withdrawn; // Total withdrawn from this stake
        uint penalty; // Total penalty on this stale

        uint rewards;
    }

    struct User {
        address wallet; // Wallet Address
        Stake[] stakes;
    }

    mapping (address => User) public users;

    uint[] public refPoolBonuses;
    uint[] public sponsorPoolBonuses;

    uint public maxContractBalance;

    uint16 public poolCycle;
    uint32 public poolDrewAt;

    uint public refPoolBalance;
    uint public sponsorPoolBalance;

    uint public devBalance;
}
