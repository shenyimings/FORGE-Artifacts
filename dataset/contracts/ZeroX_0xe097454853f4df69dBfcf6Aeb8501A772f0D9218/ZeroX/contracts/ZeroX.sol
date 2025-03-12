// SPDX-License-Identifier: Unlicensed

pragma solidity ^0.8.16;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract ZeroX is ERC20, Ownable {

    uint256 private initialSupply = 100_000_000_000 * (10 ** 18);

    uint256 public constant taxLimit = 25;
    uint256 public frontRunnerTax = 20;
    uint256 public rewardTreasuryTaxBuy = 5;
    uint256 public rewardTreasuryTaxSell = 5;

    uint256 public maxRewardFund;
    uint256 public prevRewardPeriodStart;
    uint256 public prevRewardFund;
    uint256 public prevRewardTotal;
    uint256 public prevRewardClaimed;

    uint256 public nextRewardPeriodStart;
    uint256 public nextRewardFund;
    uint256 public nextRewardTotal;
    
    uint256 private constant denominator = 100;

    mapping(address => bool) public frontRunnerList;
    mapping(address => bool) public excludedList;

    address public panCakeSwapV2PairAddr;
    address public dappContractAddr;
    address public treasuryAddr;


    event Rewarded(address indexed player, uint256 dappTokens, uint256 realTokens);
    event DappPointsAdded(address indexed player, uint256 dappTokens);

    constructor() ERC20("ZeroX", "ZEROX")
    {
        setExcluded(msg.sender);
        setExcluded(address(this));
        _mint(msg.sender, initialSupply);
        maxRewardFund = initialSupply / 100;
    }

    function rescueBNB() external onlyOwner {
        payable(msg.sender).transfer(address(this).balance);
    }

    receive() external payable {}

    function checkRewardPeriod(uint256 periodStart) private {
        if (periodStart > nextRewardPeriodStart) {
            (prevRewardPeriodStart, nextRewardPeriodStart) = (nextRewardPeriodStart, periodStart);
            prevRewardTotal = nextRewardTotal;
            prevRewardClaimed = 0;
            nextRewardTotal = 0;
            if (nextRewardFund < 1) {
                nextRewardFund = prevRewardFund;
            }
        }
    }

    function setRewardFund(uint256 _rewardFund) external onlyOwner {
        require(_rewardFund <= maxRewardFund);
        uint256 dayStart = (block.timestamp / 86400) * 86400;
        require(block.timestamp > dayStart && block.timestamp < dayStart + 3600);
        checkRewardPeriod(dayStart);
        prevRewardFund = _rewardFund;
    }

    function addRewardTotal(uint256 _dappPoints, address _addr) external {
        require(dappContractAddr == msg.sender);
        uint256 periodStart = (block.timestamp / 86400) * 86400;
        checkRewardPeriod(periodStart);
        nextRewardTotal += _dappPoints;
        emit DappPointsAdded(_addr, _dappPoints);
    }

    function getReward(uint256 _dappPoints, address _addr) external returns (uint256) {
        require(dappContractAddr == msg.sender);
        uint256 periodStart = (block.timestamp / 86400) * 86400;
        require(periodStart + 3600 <= block.timestamp, "Reward time starts at 1:00 AM UTC");
        checkRewardPeriod(periodStart);
        require(prevRewardTotal - prevRewardClaimed >= _dappPoints);
        require(balanceOf(address(this)) > 0 && _dappPoints > 0);
        uint256 paySum = (((prevRewardFund * 1000) / prevRewardTotal) * _dappPoints) / 1000;
        _transfer(address(this), _addr, paySum);
        prevRewardClaimed += _dappPoints;
        emit Rewarded(_addr, paySum, _dappPoints);
        return paySum;
    }

    function _transfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal override virtual {

        if (isExcluded(sender) || isExcluded(recipient)) {
            super._transfer(sender, recipient, amount);
            return;
        }

        uint256 baseUnit = amount / denominator;
        uint256 tax = 0;

        if (isFrontRunner(sender) || isFrontRunner(recipient)) {
            tax = baseUnit * frontRunnerTax;
        } else {
            if (sender == panCakeSwapV2PairAddr) {
                tax = baseUnit * rewardTreasuryTaxBuy;
            } else if (recipient == panCakeSwapV2PairAddr) {
                tax = baseUnit * rewardTreasuryTaxSell;
            }
        }

        if (tax > 0) {
            _transfer(sender, treasuryAddr, tax);
        }

        amount -= tax;

        super._transfer(sender, recipient, amount);
    }

    function setRewardTreasuryTax(uint256 _buy, uint256 _sell) public onlyOwner {
        require(_buy <= taxLimit && _sell <= taxLimit, "ERC20: value higher than tax limit");
        rewardTreasuryTaxBuy = _buy;
        rewardTreasuryTaxSell = _sell;
    }

    function setDappContract(address _addr) external onlyOwner {
        dappContractAddr = _addr;
    }

    function setTreasuryAddress(address _addr) external onlyOwner {
        treasuryAddr = _addr;
    }

    function setPanCakeSwapV2Pair(address _addr) external onlyOwner {
        panCakeSwapV2PairAddr = _addr;
    }

    function setExcluded(address account) public onlyOwner {
        require(!isExcluded(account), "ERC20: Account is already excluded");
        excludedList[account] = true;
    }

    function removeExcluded(address account) public onlyOwner {
        require(isExcluded(account), "ERC20: Account is not excluded");
        excludedList[account] = false;
    }

    function addFrontRunner(address account) public onlyOwner {
        require(!isFrontRunner(account), "ERC20: Account is already marked as front-runner");
        frontRunnerList[account] = true;
    }

    function removeFrontRunner(address account) public onlyOwner {
        require(isFrontRunner(account), "ERC20: Account is not front-runner");
        frontRunnerList[account] = false;
    }

    function setFrontRunnerTax(uint256 _tax) public onlyOwner {
        require(_tax <= taxLimit, "ERC20: tax value higher than tax limit");
        frontRunnerTax = _tax;
    }

    function isExcluded(address account) public view returns (bool) {
        return excludedList[account];
    }

    function isFrontRunner(address account) public view returns (bool) {
        return frontRunnerList[account];
    }
}