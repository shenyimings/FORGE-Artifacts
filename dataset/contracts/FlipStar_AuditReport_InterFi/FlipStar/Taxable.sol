//SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.7;

import "./Libraries.sol";
import "./Interfaces.sol";
import "./BaseErc20.sol";

contract TaxDistributor {
    using SafeMath for uint256;

    address public tokenPair;
    address public routerAddress;
    address private _token;
    address private _wbnb;

    IDEXRouter private _router;

    bool public inSwap;
    uint256 public lastSwapTime;

    enum TaxType { WALLET, DIVIDEND, LIQUIDITY }
    struct Tax {
        string taxName;
        uint256 buyTaxPercentage;
        uint256 sellTaxPercentage;
        uint256 taxPool;
        TaxType taxType;
        address location;
        uint256 share;
    }
    Tax[] public taxes;

    event TaxesDistributed(uint256 tokensSwapped, uint256 ethReceived);

    modifier onlyToken() {
        require(msg.sender == _token, "no permissions");
        _;
    }

    modifier notInSwap() {
        require(inSwap == false, "already swapping");
        _;
    }

    constructor (address router, address pair, address wbnb) {
        _token = msg.sender;
        _wbnb = wbnb;
        _router = IDEXRouter(router);
        tokenPair = pair;
        routerAddress = router;
    }

    receive() external payable {}

    function createWalletTax(string memory name, uint256 buyTax, uint256 sellTax, address wallet) public onlyToken {
        taxes.push(Tax(name, buyTax, sellTax, 0, TaxType.WALLET, wallet, 0));
    }
    
    function createDividendTax(string memory name, uint256 buyTax, uint256 sellTax, address dividendDistributor) public onlyToken {
        taxes.push(Tax(name, buyTax, sellTax, 0, TaxType.DIVIDEND, dividendDistributor, 0));
    }
    
    function createLiquidityTax(string memory name, uint256 buyTax, uint256 sellTax) public onlyToken {
        taxes.push(Tax(name, buyTax, sellTax, 0, TaxType.LIQUIDITY, address(0), 0));
    }

    function distribute() public payable onlyToken notInSwap {
        inSwap = true;

        address[] memory path = new address[](2);
        path[0] = _token;
        path[1] = _wbnb;

        uint256 totalTokens;
        for (uint256 i = 0; i < taxes.length - 1; i++) {
            if (taxes[i].taxType == TaxType.LIQUIDITY) {
                uint256 half = taxes[i].taxPool.div(2);
                totalTokens += taxes[i].taxPool.sub(half);
            } else {
                totalTokens += taxes[i].taxPool;
            }
        }
        
        uint256 balanceBefore = address(this).balance;
        _router.swapExactTokensForETH(
            totalTokens,
            0,
            path,
            address(this),
            block.timestamp
        );
        uint256 amountBNB = address(this).balance.sub(balanceBefore);

        // Calculate the distribution
        uint256 toDistribute = amountBNB;
        for (uint256 i = 0; i < taxes.length - 1; i++) {
            uint256 share = amountBNB.mul(taxes[i].taxPool).div(totalTokens);
            taxes[i].share = share;
            toDistribute = toDistribute.sub(share);
        }
        taxes[taxes.length - 1].share = toDistribute;

        // Distribute the coins
        for (uint256 i = 0; i < taxes.length; i++) {
            
            if (taxes[i].taxType == TaxType.WALLET) {
                payable(taxes[i].location).transfer(taxes[i].share);
            }
            else if (taxes[i].taxType == TaxType.DIVIDEND) {
                IDividendDistributor(taxes[i].location).deposit{value: taxes[i].share}();
            }
            else if (taxes[i].taxType == TaxType.LIQUIDITY) {
                if(taxes[i].share > 0){
                    _router.addLiquidityETH{value: taxes[i].share}(
                        _token,
                        taxes[i].taxPool.div(2),
                        0,
                        0,
                        BaseErc20(_token).owner(),
                        block.timestamp
                    );
                }
            }
            
            taxes[i].taxPool = 0;
            taxes[i].share = 0;
        }

        emit TaxesDistributed(totalTokens, amountBNB);

        lastSwapTime = block.timestamp;
        inSwap = false;
    }

    function getSellTax() public onlyToken view returns (uint256) {
        uint256 taxAmount;
        for (uint256 i = 0; i < taxes.length; i++) {
            taxAmount += taxes[i].sellTaxPercentage;
        }
        return taxAmount;
    }

    function getBuyTax() public onlyToken view returns (uint256) {
        uint256 taxAmount;
        for (uint256 i = 0; i < taxes.length; i++) {
            taxAmount += taxes[i].buyTaxPercentage;
        }
        return taxAmount;
    }
    
    function setTaxWallet(string memory taxName, address wallet) public onlyToken {
        bool updated;
        for (uint256 i = 0; i < taxes.length; i++) {
            if (taxes[i].taxType == TaxType.WALLET && compareStrings(taxes[i].taxName, taxName)) {
                taxes[i].location = wallet;
                updated = true;
            }
        }
        require(updated, "could not find tax to update");
    }

    function setSellTax(string memory taxName, uint256 taxPercentage) public onlyToken {
        bool updated;
        for (uint256 i = 0; i < taxes.length; i++) {
            if (compareStrings(taxes[i].taxName, taxName)) {
                taxes[i].sellTaxPercentage = taxPercentage;
                updated = true;
            }
        }
        require(updated, "could not find tax to update");
        require(getSellTax() <= 10000, "tax cannot be more than 100%");
    }

    function setBuyTax(string memory taxName, uint256 taxPercentage) public onlyToken {
        bool updated;
        for (uint256 i = 0; i < taxes.length; i++) {
            //if (taxes[i].taxName == taxName) {
            if (compareStrings(taxes[i].taxName, taxName)) {
                taxes[i].buyTaxPercentage = taxPercentage;
                updated = true;
            }
        }
        require(updated, "could not find tax to update");
        require(getBuyTax() <= 10000, "tax cannot be more than 100%");
    }

    function takeSellTax(uint256 value) public onlyToken returns (uint256) {
        for (uint256 i = 0; i < taxes.length; i++) {
            if (taxes[i].sellTaxPercentage > 0) {
                uint256 taxAmount = value.mul(taxes[i].sellTaxPercentage).div(10000);
                taxes[i].taxPool += taxAmount;
                value = value.sub(taxAmount);
            }
        }
        return value;
    }

    function takeBuyTax(uint256 value) public onlyToken returns (uint256) {
        for (uint256 i = 0; i < taxes.length; i++) {
            if (taxes[i].buyTaxPercentage > 0) {
                uint256 taxAmount = value.mul(taxes[i].buyTaxPercentage).div(10000);
                taxes[i].taxPool += taxAmount;
                value = value.sub(taxAmount);
            }
        }
        return value;
    }
    
    
    
    // Private methods
    function compareStrings(string memory a, string memory b) public pure returns (bool) {
        return (keccak256(abi.encodePacked((a))) == keccak256(abi.encodePacked((b))));
    }
}


abstract contract Taxable is BaseErc20 {
    using SafeMath for uint256;
    
    TaxDistributor taxDistributor;
    mapping (address => bool) public exchanges;
    uint256 public minimumTimeBetweenSwaps;
    uint256 public minimumTokensBeforeSwap;
    mapping (address => bool) public excludedFromTax;
    
    
    /**
     * @dev Return the current total sell tax from the tax distributor
     */
    function sellTax() public view returns (uint256) {
        return taxDistributor.getSellTax();
    }

    /**
     * @dev Return the current total sell tax from the tax distributor
     */
    function buyTax() public view returns (uint256) {
        return taxDistributor.getBuyTax();
    }

    /**
     * @dev Return the address of the tax distributor contract
     */
    function taxDistributorAddress() public view returns (address) {
        return address(taxDistributor);
    }    
    
    
    // Overrides
    
    function isAlwaysExempt(address who) internal virtual override returns (bool) {
         return (super.isAlwaysExempt(who) || who == address(taxDistributor) || exchanges[who]);
    }
    
    function calculateTransferAmount(address from, address to, uint256 value) internal virtual override returns (uint256) {
        
        uint256 amountAfterTax = value;

        if (excludedFromTax[from] == false && excludedFromTax[to] == false && launched) {
            if (exchanges[from]) {
                // we are BUYING
                amountAfterTax = taxDistributor.takeBuyTax(value);
            } else {
                // we are SELLING
                amountAfterTax = taxDistributor.takeSellTax(value);
            }
        }

        uint256 taxAmount = value.sub(amountAfterTax);
        if (taxAmount > 0) {
            _balances[address(taxDistributor)] = _balances[address(taxDistributor)].add(taxAmount);
            emit Transfer(from, address(taxDistributor), taxAmount);
        }
        return super.calculateTransferAmount(from, to, amountAfterTax);
    }


    function postTransfer(address from, address to) override virtual internal {
        uint256 timeSinceLastSwap = block.timestamp - taxDistributor.lastSwapTime();
        if (taxDistributor.inSwap() == false &&
            launched && 
            timeSinceLastSwap >= minimumTimeBetweenSwaps &&
            _balances[address(taxDistributor)] >= minimumTokensBeforeSwap) {
            try taxDistributor.distribute() {} catch {}
        }
        super.postTransfer(from, to);
    }
    
    
    
    // Admin methods
    
    
    function setExcludedFromTax(address who, bool enabled) public onlyOwner {
        excludedFromTax[who] = enabled;
    }

    function setTaxDistributionThresholds(uint256 minAmount, uint256 minTime) public onlyOwner {
        minimumTokensBeforeSwap = minAmount;
        minimumTimeBetweenSwaps = minTime;
    }
    
    function setSellTax(string memory taxName, uint256 taxAmount) public onlyOwner {
        taxDistributor.setSellTax(taxName, taxAmount);
    }

    function setBuyTax(string memory taxName, uint256 taxAmount) public onlyOwner {
        taxDistributor.setBuyTax(taxName, taxAmount);
    }
    
    function setWallets(string memory taxName, address wallet) public onlyOwner {
        taxDistributor.setTaxWallet(taxName, wallet);
    }
    
    function runSwapManually() public onlyOwner isLaunched {
        taxDistributor.distribute();
    }
}