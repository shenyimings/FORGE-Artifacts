//SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.7;

import "./Interfaces.sol";
import "./BaseErc20.sol";

contract DividendDistributor is IDividendDistributor {
    using SafeMath for uint256;

    address private _token;
    address private _distributor;

    struct Share {
        uint256 amount;
        uint256 totalExcluded;
        uint256 totalRealised;
    }

    address[] private shareholders;
    mapping (address => uint256) private shareholderIndexes;
    mapping (address => uint256) private shareholderClaims;

    mapping (address => Share) public shares;

    uint256 public totalShares;
    uint256 public totalDividends;
    uint256 public totalDistributed;
    uint256 public dividendsPerShare;
    uint256 public dividendsPerShareAccuracyFactor = 10 ** 36;

    uint256 public minPeriod = 1 hours;
    uint256 public minDistribution = 1 * (10 ** 18);

    uint256 private currentIndex;

    event DividendsDistributed(uint256 amountDistributed);

    modifier onlyToken() {
        require(msg.sender == _token, "can only be called by the parent token");
        _;
    }

    modifier onlyDistributor() {
        require(msg.sender == _distributor, "can only be called by the tax distributor");
        _;
    }

    constructor (address distributor) {
        _token = msg.sender;
        _distributor = distributor;
    }

    function setDistributionCriteria(uint256 _minPeriod, uint256 _minDistribution) external override onlyToken {
        minPeriod = _minPeriod;
        minDistribution = _minDistribution;
    }

    function setShare(address shareholder, uint256 amount) external override onlyToken {
        if(shares[shareholder].amount > 0){
            distributeDividend(shareholder);
        }

        if(amount > 0 && shares[shareholder].amount == 0){
            addShareholder(shareholder);
        }else if(amount == 0 && shares[shareholder].amount > 0){
            removeShareholder(shareholder);
        }

        totalShares = totalShares.sub(shares[shareholder].amount).add(amount);
        shares[shareholder].amount = amount;
        shares[shareholder].totalExcluded = getCumulativeDividends(shares[shareholder].amount);
    }

    function deposit() external payable override onlyDistributor {
        uint256 amount = msg.value;
        totalDividends = totalDividends.add(amount);
        dividendsPerShare = dividendsPerShare.add(dividendsPerShareAccuracyFactor.mul(amount).div(totalShares));
    }

    function process(uint256 gas) external override onlyToken {
        uint256 shareholderCount = shareholders.length;

        if(shareholderCount == 0) { return; }

        uint256 gasUsed;
        uint256 gasLeft = gasleft();
        uint256 iterations;
        uint256 distributed;

        while(gasUsed < gas && iterations < shareholderCount) {
            if(currentIndex >= shareholderCount){
                currentIndex = 0;
            }

            if(shouldDistribute(shareholders[currentIndex])){
                distributed += distributeDividend(shareholders[currentIndex]);
            }

            gasUsed = gasUsed.add(gasLeft.sub(gasleft()));
            gasLeft = gasleft();
            currentIndex++;
            iterations++;
        }

        emit DividendsDistributed(distributed);
    }

    function shouldDistribute(address shareholder) private view returns (bool) {
        return shareholderClaims[shareholder] + minPeriod < block.timestamp
        && getUnpaidEarnings(shareholder) > minDistribution;
    }

    function distributeDividend(address shareholder) private returns (uint256){
        if(shares[shareholder].amount == 0){ return 0; }

        uint256 amount = getUnpaidEarnings(shareholder);
        if (amount > 0) {
            totalDistributed = totalDistributed.add(amount);
            payable(shareholder).transfer(amount);
            shareholderClaims[shareholder] = block.timestamp;
            shares[shareholder].totalRealised = shares[shareholder].totalRealised.add(amount);
            shares[shareholder].totalExcluded = getCumulativeDividends(shares[shareholder].amount);
        }
        return amount;
    }

    function claimDividend() external {
        distributeDividend(msg.sender);
    }

    function getUnpaidEarnings(address shareholder) public view returns (uint256) {
        if(shares[shareholder].amount == 0){ return 0; }

        uint256 shareholderTotalDividends = getCumulativeDividends(shares[shareholder].amount);
        uint256 shareholderTotalExcluded = shares[shareholder].totalExcluded;

        if(shareholderTotalDividends <= shareholderTotalExcluded){ return 0; }

        return shareholderTotalDividends.sub(shareholderTotalExcluded);
    }

    function getCumulativeDividends(uint256 share) private view returns (uint256) {
        return share.mul(dividendsPerShare).div(dividendsPerShareAccuracyFactor);
    }

    function addShareholder(address shareholder) private {
        shareholderIndexes[shareholder] = shareholders.length;
        shareholders.push(shareholder);
    }

    function removeShareholder(address shareholder) private {
        shareholders[shareholderIndexes[shareholder]] = shareholders[shareholders.length-1];
        shareholderIndexes[shareholders[shareholders.length-1]] = shareholderIndexes[shareholder];
        shareholders.pop();
    }
}

abstract contract Dividends is BaseErc20 {
    IDividendDistributor dividendDistributor;
    bool autoDistributeDividends;
    mapping (address => bool) public excludedFromDividends;
    uint256 distributorGas;
    
    /**
     * @dev Return the address of the dividend distributor contract
     */
    function dividendDistributorAddress() public view returns (address) {
        return address(dividendDistributor);
    }
    
    
    // Overrides
    
    function isAlwaysExempt(address who) internal virtual override returns (bool) {
        return (super.isAlwaysExempt(who) || who == address(dividendDistributor));
    }
    
    function postTransfer(address from, address to) internal virtual override {
        if (excludedFromDividends[from] == false) {
            dividendDistributor.setShare(from, _balances[from]);
        }
        if (excludedFromDividends[to] == false) {
            dividendDistributor.setShare(to, _balances[to]);
        }
        if (autoDistributeDividends) {
            try dividendDistributor.process(distributorGas) {} catch {}
        }
        super.postTransfer(from, to);
    }
    
    
    // Admin methods
    
    function setDividendDistributionThresholds(uint256 minAmount, uint256 minTime, uint256 gas) public onlyOwner {
        distributorGas = gas;
        dividendDistributor.setDistributionCriteria(minTime, minAmount);
    }

    function setAutoDistributeDividends(bool enabled) public onlyOwner {
        autoDistributeDividends = enabled;
    }

    function setIsDividendExempt(address who, bool isExempt) public onlyOwner {
        require(who != address(this) && isAlwaysExempt(who) == false, "this address cannot receive shares");
        excludedFromDividends[who] = isExempt;
        if (isExempt){
            dividendDistributor.setShare(who, 0);
        } else {
            dividendDistributor.setShare(who, _balances[who]);
        }
    }

    function runDividendsManually(uint256 gas) public onlyOwner {
        dividendDistributor.process(gas);
    }
}