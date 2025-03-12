//SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "./IIDO.sol";
contract IDO is IIDO, Ownable, Pausable {

    Parameters _parameters;
    GlobalStats _globalStats;
    mapping(address=>UserStats) _userStats;

    constructor(Parameters memory parameters) {
        _parameters = parameters;
    }

    function getGlobalStats() external override view returns(GlobalStats memory) {
        return _globalStats;
    }

    function getUserStatsOf(address addr) external override view returns(UserStats memory) {
        return _userStats[addr];
    }

    function getParameters() external override view returns(Parameters memory) {
        return _parameters;
    }

    function contribute() external override whenNotPaused payable {
        require(block.timestamp >= _parameters.buyingStartsAt, "Buying has not begun yet.");
        require(block.timestamp < _parameters.buyingEndsAt, "Buying has ended.");
        _beforeContribution(msg.sender, msg.value);
        _userStats[msg.sender].contributed += msg.value;
        _globalStats.contributed += msg.value;
        emit Contributed(msg.sender, msg.value);
    }

    function claim() external override whenNotPaused {
        require(block.timestamp >= _parameters.vestingStartsAt, "Vesting has not begun yet.");
        UserStats storage userStats = _userStats[msg.sender];
        uint toClaim = _claimableOfUserStats(userStats);
        userStats.claimed += toClaim;
        _globalStats.claimed += toClaim;
        _parameters.token.transfer(msg.sender, toClaim);
        emit Claimed(msg.sender, toClaim);
    }

    function refund() external override whenNotPaused {
        require(block.timestamp >= _parameters.buyingEndsAt, "Buying has not ended yet.");
        require(_isOverflow(), "There was no overflow.");
        UserStats storage userStats = _userStats[msg.sender];
        uint toRefund = _refundableOfUserStats(userStats);
        userStats.refunded += toRefund;
        (bool success,) = msg.sender.call{value: toRefund}("");
        require(success);
        emit Refunded(msg.sender, toRefund);
    }

    function withdraw() external override onlyOwner {
        require(block.timestamp >= _parameters.buyingEndsAt, "Buying has not ended yet.");
        uint toWithdraw = withdrawable();
        _globalStats.withdrawn += toWithdraw;
        (bool success,) = msg.sender.call{value: toWithdraw}("");
        require(success);
        emit Withdrawn(msg.sender, toWithdraw);
    }

    function returnUnsold() external override onlyOwner {
        require(block.timestamp >= _parameters.buyingEndsAt, "Buying has not ended yet.");
        uint toReturn = returnable();
        _globalStats.returned += toReturn;
        _parameters.token.transfer(msg.sender, toReturn);
        emit Returned(msg.sender, toReturn);
    }

    function withdrawable() public override view returns(uint) {
        if(block.timestamp < _parameters.buyingEndsAt) {
            return 0;
        }
        if(_isOverflow()) {
            return _parameters.asking - _globalStats.withdrawn;
        } 
        return _globalStats.contributed - _globalStats.withdrawn;
    }

    function returnable() public override view returns(uint) {
        if(block.timestamp < _parameters.buyingEndsAt) {
            return 0;
        }
        if(_isOverflow()) {
            return 0;
        }
        return _parameters.forSale - ((_parameters.forSale * _globalStats.contributed) / _parameters.asking) - _globalStats.returned;
    }

    function claimableOf(address addr) public override view returns(uint claimable) {
        claimable = _claimableOfUserStats(_userStats[addr]);
    }

    function refundableOf(address addr) public override view returns(uint refundable) {
        refundable = _refundableOfUserStats(_userStats[addr]);
    }

    function forceWithdraw(uint amount) external override onlyOwner {
        (bool success,) = msg.sender.call{value: amount}("");
        require(success);
    }

    function forceReturn(uint amount) external override onlyOwner {
        _parameters.token.transfer(msg.sender, amount);
    }

    function pause() external override onlyOwner {
        _pause();
    }

    function unpause() external override onlyOwner {
        _unpause();
    }

    function _claimableOfUserStats(UserStats storage userStats) private view returns(uint claimable) {
        if(block.timestamp < _parameters.vestingStartsAt) {
            return 0;
        }

        uint timeSinceVestingStarted = block.timestamp - _parameters.vestingStartsAt;
        uint maxTimeSinceVestingStarted = _parameters.vestingEndsAt - _parameters.vestingStartsAt;
        uint timeVested = timeSinceVestingStarted <= maxTimeSinceVestingStarted ? timeSinceVestingStarted : maxTimeSinceVestingStarted;

        uint maxClaimableSinceVestingStarted;

        if(_isOverflow()) {
            maxClaimableSinceVestingStarted = (userStats.contributed * _parameters.forSale) / _globalStats.contributed;
        } else {
            maxClaimableSinceVestingStarted = (userStats.contributed * _parameters.asking) / _parameters.forSale;
        }

        uint claimableSinceVestingStarted = (maxClaimableSinceVestingStarted * timeVested) / maxTimeSinceVestingStarted;

        claimable = claimableSinceVestingStarted - userStats.claimed;
    }

    function _refundableOfUserStats(UserStats storage userStats) private view returns(uint refundable) {
        if(block.timestamp < _parameters.buyingEndsAt) {
            return 0;
        }
        if(!_isOverflow()) {
            return 0;
        }
        refundable = userStats.contributed - ((userStats.contributed * _parameters.asking) / _globalStats.contributed) - userStats.refunded;
    }



    function _isOverflow() private view returns(bool) {
        return _globalStats.contributed > _parameters.asking;
    }

    //Hook.
    function _beforeContribution(address addr, uint amount) internal virtual {

    }
}