// SPDX-License-Identifier: MIT

pragma solidity ^0.6.12;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/math/Math.sol";

/**
@notice Linear release of BOR
 */
contract TimeDistribution is Ownable {
    using SafeMath for uint256;
    using Math for uint256;

    IERC20 public token;
    address public distributor;

    struct DistributionInfo {
        uint256 amount;
        uint256 claimedAmount;
        uint256 beginTs;
        uint256 endTs;
        uint256 duration;
    }

    mapping(address => DistributionInfo) public infos;

    constructor(IERC20 _token, address _distributor) public {
        token = _token;
        distributor = _distributor;
    }

    function userTotalToken() public view returns (uint256) {
        return infos[msg.sender].amount;
    }

    function claimed() public view returns (uint256) {
        return infos[msg.sender].claimedAmount;
    }

    function setDistributor(address _distributor) public onlyOwner {
        distributor = _distributor;
    }

    function addInfo(
        address account,
        uint256 amount,
        uint256 beginTs,
        uint256 endTs
    ) public onlyOwner {
        require(infos[account].amount == 0, "Timedistribution::account is not a new user");
        require(amount != 0, "TimeDistribution::addInfo: amount should not 0");
        require(
            beginTs >= block.timestamp,
            "TimeDistribution::addInfo: begin too early"
        );
        require(
            endTs >= block.timestamp,
            "TimeDistribution::addInfo: end too early"
        );
        infos[account] = DistributionInfo(
            amount,
            0,
            beginTs,
            endTs,
            endTs.sub(beginTs)
        );
        emit AddInfo(account, amount, beginTs, endTs);
    }

    // careful gas
    function addMultiInfo(address[] memory accounts, uint256[] memory amounts, uint256[] memory beginTsArray, uint256[] memory endTsArray) public onlyOwner {
        require(accounts.length == amounts.length, "TimeDistribution::addMultiInfo:function params length not equal");
        require(accounts.length == beginTsArray.length, "TimeDistribution::addMultiInfo:function params length not equal");
        require(accounts.length == endTsArray.length, "TimeDistribution::addMultiInfo:function params length not equal");
        for(uint256 i=0; i < accounts.length; i++) {
            addInfo(accounts[i], amounts[i], beginTsArray[i], endTsArray[i]);
        }
    }

    function pendingClaim() public view returns (uint256) {
        if(infos[msg.sender].amount == 0) {
            return 0;
        }
        DistributionInfo storage info = infos[msg.sender];
        uint256 nowtime = Math.min(block.timestamp, info.endTs);
        return
            (nowtime.sub(info.beginTs)).mul(info.amount).div(info.duration).sub(
                info.claimedAmount
            );
    }

    function claim() public {
        uint256 claimAmount = pendingClaim();
        DistributionInfo storage info = infos[msg.sender];
        info.claimedAmount = info.claimedAmount.add(claimAmount);
        token.transferFrom(distributor, msg.sender, claimAmount);
        emit ClaimToken(msg.sender, claimAmount);
    }

    // function changeUser(address newUser) public {
    //     require(infos[newUser].amount == 0, "Timedistribution::newUser is not a new user");
    //     infos[newUser] = infos[msg.sender];
    //     delete infos[msg.sender];
    //     emit UserChanged(msg.sender, newUser);
    // }

    function changeUserAdmin(address oldUser, address newUser) public onlyOwner {
        require(infos[newUser].amount == 0, "Timedistribution::newUser is not a new user");
        infos[newUser] = infos[oldUser];
        delete infos[oldUser];
        emit UserChanged(oldUser, newUser);
    }

    event AddInfo(
        address account,
        uint256 amount,
        uint256 beginTs,
        uint256 endTs
    );
    event ClaimToken(address account, uint256 amount);
    event UserChanged(address oldUser, address newUser);
}
