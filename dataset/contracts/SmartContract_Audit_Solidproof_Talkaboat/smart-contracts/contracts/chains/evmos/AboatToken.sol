// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.7;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import "../../libraries/TransferHelper.sol";
import "./libraries/Liquify.sol";
import "../../interfaces/IMasterEntertainer.sol";

import "../../interfaces/IAboatToken.sol";


/** @dev Implements Liquify which implements the TimeLock library.
 * @dev We use the maintainer for to hold the ability to change important attributes
 * @dev Owner will be given to the MasterEntertainer contract to mint new tokens for staking/yield farming
*/
contract AboatToken is ERC20, Liquify, IAboatToken {
    using SafeMath for uint256;
    using Address for address;
    
    /* =====================================================================================================================
                                                        Variables
    ===================================================================================================================== */
    uint256 public maxDistribution = 1000000000000 ether;
    
    bool public isContractActive = false;
    bool public isHighFeeActive = true;
    uint16 public maxTxQuantity = 100;
    uint16 public maxAccBalance = 300;
    uint256 public gasCost = 2100000000000000;
    
    uint public totalFeesPaid;
    uint public devFeesPaid;
    uint public donationFeesPaid;
    uint public reDistributionFeesPaid;
    uint public liquidityFeesPaid;
    
    //Master Entertainer contract
    IMasterEntertainer public _masterEntertainer;
    
    mapping(address => bool) private blacklisted;
    mapping(address => bool) private requestedWhitelist;
    
    /* =====================================================================================================================
                                                        Events
    ===================================================================================================================== */
    event ChangedHighFeeState(bool indexed state);
    event MasterEntertainerTransferred(address indexed previousMasterEntertainer, address indexed newMasterEntertainer);
    event MaxDistributionChanged(uint256 indexed newMaxDistribution);
    event RequestedWhitelist(address indexed requestee);
    event Blacklisted(address indexed user);
    event MaxAccBalanceChanged(uint16 indexed previousMaxBalance, uint16 indexed newMaxBalance);
    event MaxTransactionQuantityChanged(uint16 indexed previousMaxTxQuantity, uint16 indexed newMaxTxQuantity);
    event GasCostChanged(uint256 indexed previousGasCost, uint256 indexed newGasCost);
    /* =====================================================================================================================
                                                        Modifier
    ===================================================================================================================== */
    
    constructor() ERC20("Aboat Token", "ABOAT") {
        mint(msg.sender, 600000000000 ether);
        excludeFromAll(msg.sender);
        //updateRouter(0xa5E0829CaCEd8fFDD4De3c43696c57F7D7A678ff);
        //setTimelockEnabled();
    }
    
    /* =====================================================================================================================
                                                        Set Functions
    ===================================================================================================================== */
    function setMasterEntertainer(address _newMasterEntertainer) public onlyOwner {
        require(_newMasterEntertainer != address(_masterEntertainer) && _newMasterEntertainer != address(0), "ABOAT::setMasterEntertainer: Master entertainer can\'t equal previous master entertainer or zero address");
        address previousEntertainer = address(_masterEntertainer);
        _masterEntertainer = IMasterEntertainer(_newMasterEntertainer);
        excludeFromAll(_newMasterEntertainer);
        transferOwnership(_newMasterEntertainer);
        emit MasterEntertainerTransferred(previousEntertainer, _newMasterEntertainer);
    }
    
    function setMaxDistribution(uint256 _newDistribution) public onlyMaintainerOrOwner locked("max_distribution") {
        require(_newDistribution > totalSupply(), "ABOAT::setMaxDistribution: Distribution can't be lower than the current total supply");
        maxDistribution = _newDistribution;
        emit MaxDistributionChanged(_newDistribution);
    }
     
    function setMaxAccBalance(uint16 maxBalance) public onlyMaintainerOrOwner {
        require(maxBalance > 100, "Max account balance can't be lower than 1% of total supply");
        uint16 previousMaxBalance = maxAccBalance;
        maxAccBalance = maxBalance;
        emit MaxAccBalanceChanged(previousMaxBalance, maxAccBalance);
    }
    
    function setMaxTransactionQuantity(uint16 quantity) public onlyMaintainerOrOwner {
        require(quantity > 10, "Max transaction size can't be lower than 0.1% of total supply");
        uint16 previous = maxTxQuantity;
        maxTxQuantity = quantity;
        emit MaxTransactionQuantityChanged(previous, maxTxQuantity);
    }
    
    function setGasCost(uint256 cost) public onlyMaintainerOrOwner {
        uint256 previous = gasCost;
        gasCost = cost;
        emit GasCostChanged(previous, gasCost);
    }

    
    /* =====================================================================================================================
                                                        Get Functions
    ===================================================================================================================== */
    function isExcludedFromSenderTax(address _account) public view returns (bool) {
        return _excludedFromFeesAsSender[_account];
    }
    
    function isExcludedFromReceiverTax(address _account) public view returns (bool) {
        return _excludedFromFeesAsReceiver[_account];
    }
    
    function hasRequestedWhitelist(address user) public onlyMaintainerOrOwner view returns (bool) {
        return requestedWhitelist[user];
    }
    
    function getBalanceOf(address _user) public view returns (uint256) {
        return balanceOf(_user).add(_masterEntertainer.getBalanceOf(_user, 0));
    }
    
    function getTaxFee(address _sender) public view returns (uint256) {
        //Anti-Bot: The first Blocks will have a 90% fee
        if(isHighFeeActive) {
            return 9000;
        }
        uint balance = getBalanceOf(_sender);
        if(balance > totalSupply()) {
            return maximumTransferTaxRate;
        }
        else if(balance < totalSupply() / 100000) {
            return minimumTransferTaxRate;
        }
        uint tax = balance * 100000 / totalSupply();
        if(tax > 100) {
            uint realTax = minimumTransferTaxRate + tax - 100;
            return realTax > maximumTransferTaxRate ? maximumTransferTaxRate : realTax;
        } else {
            return minimumTransferTaxRate;
        }
    }
    
    function liquidityPair() public override view returns (address) {
        return _liquidityPair;
    }
    
    function getLiquidityTokenAddress() public view returns (address) {
        IUniswapV2Pair pair = IUniswapV2Pair(_liquidityPair);
        address tokenA = address(pair.token0());
        address tokenB = address(pair.token1());
        return tokenA != address(this) ? tokenA : tokenB;
    }
    
    function liquidityTokenBalance() public view returns (uint256) {
        return IERC20(getLiquidityTokenAddress()).balanceOf(address(this));
    }
    
    function canMintNewCoins(uint256 _amount) public override view returns (bool) {
        return totalSupply() + _amount <= maxDistribution;
    }
    
    function getCirculatingSupply() public view returns (uint256) {
        return totalSupply().sub(balanceOf(_rewardWallet));
    }
    
    /* =====================================================================================================================
                                                    Utility Functions
    ===================================================================================================================== */
    
    receive() external payable {}
    
    function activateHighFee() public onlyMaintainerOrOwner {
        isHighFeeActive = true;
        emit ChangedHighFeeState(isHighFeeActive);
    }
    
    function deactivateHighFee() public onlyMaintainerOrOwner {
        isHighFeeActive = false;
        isContractActive = true;
        emit ChangedHighFeeState(isHighFeeActive);
    }
    
    function activateContract() public onlyMaintainerOrOwner {
        isContractActive = true;
    }
    
    function blacklist(address user) public onlyMaintainerOrOwner {
        blacklisted[user] = true;
        emit Blacklisted(user);
    }
    
    function whitelist(address user) public onlyMaintainerOrOwner {
        blacklisted[user] = true;
        requestedWhitelist[user] = false;
    }
    
    function requestWhitelist() public payable {
        require(blacklisted[msg.sender], "ABOAT::requestWhitelist: You are not blacklisted!");
        require(!requestedWhitelist[msg.sender], "ABOAT::requestWhitelist: You already requested whitelist!");
        require(msg.value >= gasCost, "ABOAT::requestWhitelist: Amount of bnb to claim should carry the cost to add the claimable");
        TransferHelper.safeTransferETH(_devWallet, msg.value);
        requestedWhitelist[msg.sender] = true;
        emit RequestedWhitelist(msg.sender);
    }
    
    function claimExceedingETH() public onlyMaintainerOrOwner {
        require(address(this).balance > 0, "ABOAT::claimExceedingLiquidityTokenBalance: No exceeding balance");
        TransferHelper.safeTransferETH(msg.sender, address(this).balance);
    }
    
    function mint(address _to, uint256 _amount) public override onlyOwner {
        require(totalSupply() + _amount <= maxDistribution, "ABOAT::mint: Can't mint more aboat token than maxDistribution allows");
        _mint(_to, _amount);
    }
    
    function _transfer(address sender, address recipient, uint256 amount) internal virtual override nonReentrant {
        require(sender != address(0), "ABOAT::_transfer: transfer from the zero address");
        require(recipient != address(0), "ABOAT::_transfer: transfer to the zero address");
        require(amount > 0, "ABOAT::_transfer:Transfer amount must be greater than zero");
        require(amount <= balanceOf(sender), "ABOAT::_transfer:Transfer amount must be lower or equal senders balance");
        //Anti-Bot: If someone sends too many recurrent transactions in a short amount of time he will be blacklisted
        require(!blacklisted[sender], "ABOAT::_transfer:You're currently blacklisted. Please report to service@talkaboat.online if you want to get removed from blacklist!");
        //Anti-Bot: Disable transactions with more than 1% of total supply
        require(amount * 10000 / totalSupply() <= maxTxQuantity || sender == owner() || sender == maintainer() || _excludedFromFeesAsSender[sender] || _excludedFromFeesAsReceiver[sender], "Your transfer exceeds the maximum possible amount per transaction");
        //Anti-Whale: Only allow wallets to hold a certain percentage of total supply
        require((amount + getBalanceOf(recipient)) * 10000 / totalSupply() <= maxAccBalance || recipient == owner() || recipient == maintainer() || recipient == address(this) || _excludedFromFeesAsReceiver[recipient] || _excludedFromFeesAsSender[recipient], "ABOAT::_transfer:Balance of recipient can't exceed maxAccBalance");
        //Liquidity Provision safety
        require(isContractActive || sender == owner() || sender == maintainer() || _excludedFromFeesAsReceiver[recipient] || _excludedFromFeesAsSender[sender], "ABOAT::_transfer:Contract is not yet open for community");
        if ((!isHighFeeActive || sender == maintainer() || sender == owner() || (_excludedFromFeesAsSender[sender] && _excludedFromFeesAsReceiver[recipient])) && (recipient == address(0) || maximumTransferTaxRate == 0 || _excludedFromFeesAsReceiver[recipient] || _excludedFromFeesAsSender[sender])) {
            super._transfer(sender, recipient, amount);
        } else {
            uint256 taxAmount = amount.mul(getTaxFee(sender)).div(10000);
            uint256 reDistributionAmount = taxAmount.mul(reDistributionRate).div(100);
            uint256 devAmount = taxAmount.mul(devRate).div(100);
            uint256 donationAmount = taxAmount.mul(donationRate).div(100);
            uint256 liquidityAmount = taxAmount.sub(reDistributionAmount.add(devAmount).add(donationAmount));
            require(taxAmount == reDistributionAmount + liquidityAmount + devAmount + donationAmount, "ABOAT::transfer: Fee amount does not equal the split fee amount");
            uint256 sendAmount = amount.sub(taxAmount);
            require(amount == sendAmount + taxAmount, "ABOAT::transfer: amount to send with tax amount exceeds maximum possible amount");
            super._transfer(sender, address(this), liquidityAmount + devAmount + donationAmount);
            super._transfer(sender, recipient, sendAmount);
            super._transfer(sender, _rewardWallet, reDistributionAmount);
            amount = sendAmount;
            totalFeesPaid += taxAmount;
            devFeesPaid += devAmount;
            donationFeesPaid += donationAmount;
            liquidityFeesPaid += liquidityAmount;
        }
        
        checkPriceUpdate();
    }

    function checkPriceUpdate() public {
        if(address(_masterEntertainer) != address(0)) {
            _masterEntertainer.updatePrice();
        }
    }
}