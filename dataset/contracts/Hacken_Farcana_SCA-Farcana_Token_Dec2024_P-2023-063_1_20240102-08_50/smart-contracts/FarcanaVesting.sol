// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable2Step.sol";

/// @title The FARCANA token(FAR) vesting contract
/// @author Adam Zaitov
/// @notice This smart contract is used to block investor tokens and then unlock them according to a schedule
contract TokenVesting is Ownable2Step  {
    using SafeERC20 for IERC20;

    IERC20 private token;
    
    struct VestingSchedule {
        uint256 cliff; // cliff time of the vesting start in seconds since the UNIX epoch
        uint256 duration; // duration of the vesting period in seconds
        uint256 start; // start time of the vesting period in seconds since the UNIX epoch
        uint256 totalAmount; // total amount of tokens to be released at the end of the vesting
        uint256 released;  // amount of tokens released
    }

    uint256 internal tgetime;

    uint256 internal tvl; // total value locked(in FARs)

    mapping(address => VestingSchedule[]) private vestingSchedules;

    event TokensReleased(address indexed beneficiary, uint256 amount);
    event TGEtime(uint256 new_tge_time);
    event AddedVestingSchedule(address indexed beneficiary, uint256 cliff, uint256 duration, uint256 start, uint256 totalAmount);
    event ChangedBeneficiaryAddress(address indexed lost_address, address indexed new_address);

    constructor(address token_address) Ownable(msg.sender){

        require(token_address != address(0), "Token address can not be zero");

        token = IERC20(token_address);
    }

    function setTGEtime(uint256 new_tge_time) external onlyOwner{
        require(tgetime == 0, "TGE has already set");
        tgetime = new_tge_time;
        emit TGEtime(new_tge_time);
    }

    function getTGEtime() external view returns (uint256){
        return tgetime;
    }

    function getTVL() external view returns (uint256){
        return tvl;
    }

    function getToken() external view returns (address) {
        return address(token);
    }

    function addVestingSchedule(
        address beneficiary,
        uint256 cliff,
        uint256 duration,
        uint256 start,
        uint256 totalAmount
    ) external onlyOwner {

        require(tgetime > 0, "TGE time is not set");
        require(start >= tgetime, "Start time should be greater or equal than TGE time");
        require(cliff > 0, "Cliff should be positive");
        require(duration > 0, "Duration should be positive");
        require(cliff <= duration, "Cliff should not exceed duration");
        require(beneficiary != address(0), "Beneficiary address can not be zero");

        uint totalTokensOfSmartContract = token.balanceOf(address(this));
        uint availableTokensOfSmartContract = totalTokensOfSmartContract - tvl;

        require(totalAmount <= availableTokensOfSmartContract, "The smart contract does not have enough tokens");

        VestingSchedule memory schedule = VestingSchedule({
            cliff: cliff,
            duration: duration,
            start: start,
            totalAmount: totalAmount,
            released: 0
        });

        vestingSchedules[beneficiary].push(schedule);

        tvl += totalAmount;

        emit AddedVestingSchedule(beneficiary, cliff, duration, start, totalAmount);
    }

    function claim() external {
        
        uint256 unreleased = prepareAvailableTokensForRelease(msg.sender);

        require(unreleased > 0, "No tokens are due for release");

        token.safeTransfer(msg.sender, unreleased);

        tvl -= unreleased;
    }

    function getReleasedTokens(address beneficiary) external view returns(uint256) {
        
        VestingSchedule[] storage schedules = vestingSchedules[beneficiary];

        uint256 released = 0;

        for (uint256 i = 0; i < schedules.length; i++) {
            
            VestingSchedule storage schedule = schedules[i];

            if(schedule.released > 0){
                released = released + schedule.released;
            }
        }

        return released;
    }

    function getAvailableTokens(address beneficiary) external view returns(uint256) {

        VestingSchedule[] storage schedules = vestingSchedules[beneficiary];

        uint256 unreleased = 0;

        for (uint256 i = 0; i < schedules.length; i++) {
            VestingSchedule storage schedule = schedules[i];

            if (block.timestamp < schedule.start + schedule.cliff) {
                continue;
            }

            uint256 vestedAmount = calculateVestedAmount(schedule);
            uint256 releaseable = vestedAmount - schedule.released;
            
            if (releaseable > 0) {
                unreleased = unreleased + releaseable;
            }
        }

        return unreleased;
    }

    function prepareAvailableTokensForRelease(address beneficiary) internal returns(uint256) {

        VestingSchedule[] storage schedules = vestingSchedules[beneficiary];

        uint256 unreleased = 0;

        for (uint256 i = 0; i < schedules.length; i++) {
            VestingSchedule storage schedule = schedules[i];

            if (block.timestamp < schedule.start + schedule.cliff) {
                continue;
            }

            uint256 vestedAmount = calculateVestedAmount(schedule);
            uint256 releaseable = vestedAmount - schedule.released;
            
            if (releaseable > 0) {
                unreleased = unreleased + releaseable;
                schedule.released = schedule.released + releaseable;
                emit TokensReleased(msg.sender, releaseable);
            }
        }

        return unreleased;
    }

    function calculateVestedAmount(VestingSchedule storage schedule) internal view returns (uint256) {
        uint256 currentTimestamp = block.timestamp;

        if (currentTimestamp < schedule.start) {
            return 0;
        } else if (currentTimestamp >= schedule.start + schedule.duration) {
            return schedule.totalAmount;
        } else {
            return schedule.totalAmount * (currentTimestamp - schedule.start) / schedule.duration;
        }
    }

    /// @notice This function is intended in case the beneficiary loses his wallet
    /// @dev No minting of additional tokens or premature unlocking of existing ones. Only the beneficiary's address can be replaced while maintaining the current state of token locking
    /// @param lost_address - an old address, which will be replaced
    /// @param new_address - a new address, which will be set 
    function changeBeneficiaryAddress(address lost_address, address new_address) external onlyOwner{
        
        VestingSchedule[] storage schedules = vestingSchedules[lost_address];

        vestingSchedules[new_address] = schedules;

        delete vestingSchedules[lost_address];

        emit ChangedBeneficiaryAddress(lost_address, new_address);
    }

    function getFullDataOfBeneficiary(address beneficiary) external view returns(VestingSchedule[] memory) {
        return vestingSchedules[beneficiary];
    }
}
