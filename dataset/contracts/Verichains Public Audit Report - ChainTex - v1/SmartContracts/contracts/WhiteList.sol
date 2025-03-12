pragma solidity 0.4.25;


import "./Withdrawable.sol";
import "./WhiteListInterface.sol";
import "./TRC20Interface.sol";


contract WhiteList is WhiteListInterface, Withdrawable {

    uint public weiPerSgd; // amount of weis in 1 singapore dollar
    mapping (address=>uint) public userCategory; // each user has a category defining cap on trade. 0 for standard.
    mapping (uint=>uint)    public categoryCap;  // will define cap on trade amount per category in singapore Dollar.

    constructor(address _admin) public {
        require(_admin != address(0));
        admin = _admin;
    }

    function getUserCapInWei(address user) external view returns (uint) {
        uint category = getUserCategory(user);
        return (categoryCap[category] * weiPerSgd);
    }

    event UserCategorySet(address user, uint category);

    function setUserCategory(address user, uint category) public onlyOperator {
        userCategory[user] = category;
        emit UserCategorySet(user, category);
    }

    event CategoryCapSet (uint category, uint sgdCap);

    function setCategoryCap(uint category, uint sgdCap) public onlyOperator {
        categoryCap[category] = sgdCap;
        emit CategoryCapSet(category, sgdCap);
    }

    event SgdToWeiRateSet (uint rate);

    function setSgdToEthRate(uint _sgdToWeiRate) public onlyOperator {
        weiPerSgd = _sgdToWeiRate;
        emit SgdToWeiRateSet(_sgdToWeiRate);
    }

    function getUserCategory (address user) public view returns(uint) {
        return userCategory[user];
    }
}
