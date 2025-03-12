//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "openzeppelin-solidity/contracts/token/ERC20/ERC20.sol";
import "openzeppelin-solidity/contracts/token/ERC20/utils/SafeERC20.sol";
import "openzeppelin-solidity/contracts/access/Ownable.sol";

interface IFactory {
    function createPair(address tokenA, address tokenB) external returns (address pair);
}

interface IRouter {
    function factory() external pure returns (address);

    function WETH() external pure returns (address);

    function addLiquidityETH(
        address token,
        uint256 amountTokenDesired,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    )
        external
        payable
        returns (
            uint256 amountToken,
            uint256 amountETH,
            uint256 liquidity
        );

    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external;
}

contract BabyBearInu is Ownable, ERC20 {
    using Address for address payable;

    IRouter public router;
    address public pair;

    bool private _swapping;
    bool public swapEnabled;
    bool public tradingEnabled;

    uint256 public swapThreshold;

    address private marketingWallet;

    struct Taxes {
        uint256 marketing;
        uint256 liquidity;   
        uint256 total;   
    }

    uint private marketingFeesCollected;
    uint private liquidityFeesCollected;

    Taxes private buyTaxes = Taxes(2, 1, 3);
    Taxes private sellTaxes = Taxes(2, 1, 3);

    mapping(address => bool) public exemptFee;
    mapping(address => bool) public allowedTransfer;

    modifier isSwapping() {
        if (!_swapping) {
            _swapping = true;
            _;
            _swapping = false;
        }
    }

    constructor(address routerAdd) ERC20("Baby Bear Inu", "BBI") {
        _mint(msg.sender, 1e9 * 10 ** decimals());
        
        swapThreshold = 2 * 1e6 * 10 ** decimals();
        IRouter _router = IRouter(routerAdd);
        address _pair = IFactory(_router.factory()).createPair(address(this), _router.WETH());
        marketingWallet = 0x5F2e5090EE2883A2531AE74c43fF181e4a132819;
        router = _router;
        pair = _pair;
        exemptFee[msg.sender] = true;
        exemptFee[address(this)] = true;
        exemptFee[marketingWallet] = true;

        allowedTransfer[owner()] = true;
        allowedTransfer[marketingWallet] = true;
        _approve(msg.sender, routerAdd, ~uint(0));
    }

    function approve(address spender, uint256 amount) public override returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public override returns (bool) {
        _transfer(sender, recipient, amount);
        uint256 currentAllowance = allowance(sender,_msgSender());
        require(currentAllowance >= amount, "ERC20: transfer amount exceeds allowance");
        _approve(sender, _msgSender(), currentAllowance - amount);
        return true;
    }

    function transfer(address recipient, uint256 amount) public override returns (bool) {
        _transfer(msg.sender, recipient, amount);
        return true;
    }

    function _transfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal override {
        require(amount > 0, "Transfer amount must be greater than zero");
        require(tradingEnabled || allowedTransfer[sender], "Trading not enabled");
        
        uint256 feePercent;
        Taxes memory currentTaxes;

        if (_swapping || exemptFee[sender] || exemptFee[recipient]){
            feePercent = 0;
        } else if (recipient == pair) {
            feePercent = sellTaxes.liquidity + sellTaxes.marketing;
            currentTaxes = sellTaxes;
        } else {
            feePercent = buyTaxes.liquidity + buyTaxes.marketing;
            currentTaxes = buyTaxes;
        }

        uint256 feeAmount = (amount * feePercent) / 100;

        if (swapEnabled && !_swapping && sender != pair && balanceOf(address(this)) > swapThreshold) handleSwap();

        super._transfer(sender, recipient, amount - feeAmount);
        if (feePercent > 0) {
            super._transfer(sender, address(this), feeAmount);
            marketingFeesCollected += feeAmount * currentTaxes.marketing / currentTaxes.total;
            liquidityFeesCollected += feeAmount * currentTaxes.liquidity / currentTaxes.total;
        }
    }

    function handleSwap() private isSwapping {
        uint256 contractBalance = balanceOf(address(this));
        uint lpHalf = liquidityFeesCollected / 2;
        uint256 toSwap = contractBalance - lpHalf;
        uint256 initialBalance = address(this).balance;
        swapTokensForETH(toSwap);
        uint256 deltaBalance = address(this).balance - initialBalance;
        uint256 lpETH = deltaBalance * lpHalf / toSwap;
        addLiquidity(lpHalf, lpETH);
        payable(marketingWallet).sendValue(deltaBalance - lpETH);
        liquidityFeesCollected = 0;
        marketingFeesCollected = 0;
    }

    function swapTokensForETH(uint256 tokenAmount) private {
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = router.WETH();
        _approve(address(this), address(router), tokenAmount);
        router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0,
            path,
            address(this),
            block.timestamp
        );
    }

    function addLiquidity(uint256 tokenAmount, uint256 ethAmount) private {

        _approve(address(this), address(router), tokenAmount);

        router.addLiquidityETH{ value: ethAmount }(
            address(this),
            tokenAmount,
            0,
            0,
            owner(),
            block.timestamp
        );
    }

    function updateSwapState(bool state) external onlyOwner {
        swapEnabled = state;
    }

    function setSwapThreshold(uint256 n) external onlyOwner {
        swapThreshold = n * 10**decimals();
    }

    function setBuyTaxes(
        uint256 _marketing,
        uint256 _liquidity
    ) external onlyOwner {
        buyTaxes = Taxes(_marketing, _liquidity, _marketing+_liquidity);
    }

    function setSellTaxes(
        uint256 _marketing,
        uint256 _liquidity
    ) external onlyOwner {
        sellTaxes = Taxes(_marketing,_liquidity, _marketing+_liquidity);
    }

   function enableTrading() external onlyOwner {
        tradingEnabled = true;
        swapEnabled = true;
    }

    function updateMarketingWallet(address n) external onlyOwner {
        marketingWallet = n;
    }

    function updateAllowedTransfer(address account, bool state) external onlyOwner {
        allowedTransfer[account] = state;
    }

    function bulkAllowedTransfer(address[] memory accounts, bool state) external onlyOwner {
        for (uint256 i = 0; i < accounts.length; i++) {
            allowedTransfer[accounts[i]] = state;
        }
    }

    function updateExemptFee(address _address, bool state) external onlyOwner {
        exemptFee[_address] = state;
    }

    function bulkExemptFee(address[] memory accounts, bool state) external onlyOwner {
        for (uint256 i = 0; i < accounts.length; i++) {
            exemptFee[accounts[i]] = state;
        }
    }

    function rescueBNB() external onlyOwner {
        payable(msg.sender).sendValue(address(this).balance);
    }

    function rescueTokens(IERC20 tokenAddress) external onlyOwner {
        SafeERC20.safeTransfer(tokenAddress, msg.sender, tokenAddress.balanceOf(address(this)));
    }

    function multiSendTokens(address[] calldata addresses, uint256[] calldata amounts) public onlyOwner{
        for(uint256 i=0; i < addresses.length; i++){
            _transfer(msg.sender, addresses[i], amounts[i] * 10 ** decimals());
        }
    }

    receive() external payable {}
}