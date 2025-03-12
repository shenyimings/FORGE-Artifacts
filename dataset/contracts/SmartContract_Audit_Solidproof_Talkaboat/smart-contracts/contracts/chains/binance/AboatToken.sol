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
import "../../libraries/Liquify.sol";
import "../../interfaces/IMasterEntertainer.sol";
import "../../interfaces/IAboatToken.sol";

contract AboatToken is ERC20, Liquify, IAboatToken {
    using SafeMath for uint256;
    using Address for address;    

    /* =====================================================================================================================
                                                        Variables
    ===================================================================================================================== */
    uint256 public maxDistribution = 1000000000000 ether;
    bool public isContractActive = false;
    uint16 public maxTxQuantity = 100;
    uint16 public maxAccBalance = 300;

    IMasterEntertainer _masterEntertainer;

    mapping(address => bool) private blacklisted;
    
    /* =====================================================================================================================
                                                        Events
    ===================================================================================================================== */
    event Blacklisted(address indexed user);    
    event Whitelisted(address indexed user);
    event MaxAccBalanceChanged(uint16 indexed previousMaxBalance, uint16 indexed newMaxBalance);
    event MaxTransactionQuantityChanged(uint16 indexed previousMaxTxQuantity, uint16 indexed newMaxTxQuantity);
    event ChangedContractState(bool state);
    event ChangedMasterEntertainer(address indexed newMasterEntertainer);

    constructor() ERC20("Aboat Token", "ABOAT") {
        mint(msg.sender, maxDistribution);
        excludeFromAll(msg.sender);
        updateRouter(0x10ED43C718714eb63d5aA57B78B54704E256024E);
    }

    receive() external payable {}
    
    /* =====================================================================================================================
                                                    SET FUNCTIONS
    ===================================================================================================================== */
     
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

    function setMasterEntertainer(IMasterEntertainer masterEntertainer) public onlyMaintainerOrOwner {
        _masterEntertainer = masterEntertainer;
        excludeFromAll(address(masterEntertainer));
        emit ChangedMasterEntertainer(address(_masterEntertainer));
    }

    function setContractStatus(bool state) public onlyMaintainerOrOwner {
        isContractActive = state;
        emit ChangedContractState(state);
    }

        
    /* =====================================================================================================================
                                                    GET FUNCTIONS
    ===================================================================================================================== */

    function liquidityPair() public override view returns (address) {
        return _liquidityPair;
    }
    
    function canMintNewCoins(uint256 _amount) public override pure returns (bool) {
        return false;
    }

    function isExcludedFromSenderTax(address _account) public view returns (bool) {
        return _excludedFromFeesAsSender[_account];
    }
    
    function isExcludedFromReceiverTax(address _account) public view returns (bool) {
        return _excludedFromFeesAsReceiver[_account];
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
    

    function getCirculatingSupply() public view returns (uint256) {
        return totalSupply().sub(balanceOf(_rewardWallet));
    }

    function getBalanceOf(address _user) public view returns (uint256) {
        uint256 walletBalance = balanceOf(_user);
        if(address(_masterEntertainer) != address(0)) {
            return walletBalance.add(_masterEntertainer.getBalanceOf(_user, 0));
        }
        return walletBalance;
    }

    function getTaxFee(address _sender) public view returns (uint256) {
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

        
    /* =====================================================================================================================
                                                UTILITY FUNCTIONS
    ===================================================================================================================== */
    function mint(address _to, uint256 _amount) public override onlyOwner {
        _mint(_to, _amount);
    }

    function blacklist(address user) public onlyMaintainerOrOwner {
        blacklisted[user] = true;
        emit Blacklisted(user);
    }
    
    function whitelist(address user) public onlyMaintainerOrOwner {
        blacklisted[user] = false;
        emit Whitelisted(user);
    }

    function claimExceedingETH() public onlyMaintainerOrOwner {
        require(address(this).balance > 0, "ABOAT::claimExceedingLiquidityTokenBalance: No exceeding balance");
        TransferHelper.safeTransferETH(msg.sender, address(this).balance);
    }
    
    function _transfer(address sender, address recipient, uint256 amount) internal virtual override nonReentrant {
        require(sender != address(0), "ABOAT::_transfer: transfer from the zero address");
        require(recipient != address(0), "ABOAT::_transfer: transfer to the zero address");
        require(amount > 0, "ABOAT::_transfer:Transfer amount must be greater than zero");
        require(amount <= balanceOf(sender), "ABOAT::_transfer:Transfer amount must be lower or equal senders balance");
        require(!blacklisted[sender], "ABOAT::_transfer:You're currently blacklisted. Please report to service@talkaboat.online if you want to get removed from blacklist!");
        //Anti-Bot: Disable transactions with more than 1% of total supply
        require(amount * 10000 / totalSupply() <= maxTxQuantity || sender == owner() || sender == maintainer() || _excludedFromFeesAsSender[sender] || _excludedFromFeesAsReceiver[sender], "Your transfer exceeds the maximum possible amount per transaction");
        //Anti-Whale: Only allow wallets to hold a certain percentage of total supply
        require((amount + getBalanceOf(recipient)) * 10000 / totalSupply() <= maxAccBalance || recipient == owner() || recipient == maintainer() || recipient == address(this) || _excludedFromFeesAsReceiver[recipient] || _excludedFromFeesAsSender[recipient], "ABOAT::_transfer:Balance of recipient can't exceed maxAccBalance");
        //Liquidity Provision safety
        require(isContractActive || sender == owner() || sender == maintainer() || _excludedFromFeesAsReceiver[recipient] || _excludedFromFeesAsSender[sender], "ABOAT::_transfer:Contract is not yet open for community");

        if (!isFeeActive || sender == maintainer() || sender == owner() || _excludedFromFeesAsReceiver[recipient] || _excludedFromFeesAsSender[sender]) {
            super._transfer(sender, recipient, amount);
        } else {
            uint256 taxAmount = amount.mul(getTaxFee(sender)).div(10000);
            uint256 reDistributionAmount = taxAmount.mul(reDistributionRate).div(100);
            uint256 devAmount = taxAmount.mul(devRate).div(100);
            uint256 liquidityAmount = taxAmount.sub(reDistributionAmount.add(devAmount));
            require(taxAmount == reDistributionAmount + liquidityAmount + devAmount, "ABOAT::transfer: Fee amount does not equal the split fee amount");
            uint256 sendAmount = amount.sub(taxAmount);
            require(amount == sendAmount + taxAmount, "ABOAT::transfer: amount to send with tax amount exceeds maximum possible amount");
            super._transfer(sender, address(this), liquidityAmount + devAmount);
            super._transfer(sender, recipient, sendAmount);
            super._transfer(sender, _rewardWallet, reDistributionAmount);
        }
    }
}