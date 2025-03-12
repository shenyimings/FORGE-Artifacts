// SPDX-License-Identifier: MIT
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
pragma solidity ^0.8.18;

contract KairanX is ERC20, Ownable, ERC20Burnable {
    using SafeMath for uint256;
    uint256 constant MAX_TOKENS = 27_000_000_000;
    uint8 sellFeePercentage = 5;
    uint8 buyFeePercentage = 3;
    event TaxChange(uint8 butTaxPercentage , uint8 sellTaxPercentage);
    mapping(address => bool) public isExcludedFromTax;
    address private uniswapV2Pair;
    address immutable private feeWallet;

    constructor(address _mainWallet ,address _feeWallet) ERC20("KairanX", "KIX") {
        _mint(_mainWallet, MAX_TOKENS.mul(10**18));
        feeWallet = _feeWallet;
    }
    
    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal override {
        if (!isExcludedFromTax[to] && !isExcludedFromTax[from]) {
            //The addresses are not in the excluded list so take taxes
            if (from == uniswapV2Pair) {
                //This means that the token is comming from the uniswap v2 pair i.e user is buying the token
                uint256 taxAmount = (amount.mul(buyFeePercentage)).div(100);
                super._transfer(from, to, amount.sub(taxAmount));
                super._transfer(from, feeWallet, taxAmount);
            } else if (to == uniswapV2Pair) {
                //This means that the user is selling the token
                uint256 taxAmount = (amount.mul(sellFeePercentage)).div(100);
                super._transfer(from, to, amount.sub(taxAmount));
                super._transfer(from, feeWallet, taxAmount);
            } else {
                super._transfer(from, to, amount);
            }
        }
        else{
            //The addresses are in the exculded list so not take taxes
            super._transfer(from, to, amount);
        }
    }

    function addUniswapV2PairAddress(address _uniswapPair) external onlyOwner {
        uniswapV2Pair = _uniswapPair;
    }

    function changeTaxes(uint8 _sellTax, uint8 _buyTax) public onlyOwner {
        require(_sellTax <= 10 && _sellTax > 0, "tax must be in range 1% - 25% !");
        require(_buyTax <= 10 && _buyTax > 0, "tax must be in range 1%- 25%!");
        
        sellFeePercentage = _sellTax;
        buyFeePercentage = _buyTax;
        emit TaxChange(_buyTax, _sellTax);
    }
    function addToExcludedList(address _address) external onlyOwner{
        isExcludedFromTax[_address] = true;
    }
}
