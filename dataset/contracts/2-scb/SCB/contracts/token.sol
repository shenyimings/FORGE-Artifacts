//SPDX-License-Identifier: MIT

/**
                  ▄▄                           ▄▄                                
 ▄█▀▀▀█▄█         ██                           ██              ▄▄█▀▀▀█▄████▀▀▀██▄
▄██    ▀█                                                    ▄██▀     ▀█ ██    ██
▀███▄     ▄▄█▀██▀███  ▄██▀███████████▄█████▄ ▀███  ▄██▀██    ██▀       ▀ ██    ██
  ▀█████▄▄█▀   ██ ██  ██   ▀▀ ██    ██    ██   ██ ██▀  ██    ██          ██▀▀▀█▄▄
▄     ▀████▀▀▀▀▀▀ ██  ▀█████▄ ██    ██    ██   ██ ██         ██▄         ██    ▀█
██     ████▄    ▄ ██  █▄   ██ ██    ██    ██   ██ ██▄    ▄   ▀██▄     ▄▀ ██    ▄█
█▀█████▀  ▀█████▀████▄██████▀████  ████  ████▄████▄█████▀      ▀▀█████▀▄████████ 
                                                                                 
Features:
1- Dynamic Tax System: The token has a dynamic tax system that applies different tax rates for buying, selling, and transferring tokens. These taxes are adjustable by the contract owner, providing flexibility in managing the token's ecosystem.
2- Trading Limitations: The contract enforces limitations on trading, such as maximum buy, sell, and transfer amounts. It also has a maximum wallet holding limit to prevent concentration of tokens in a single wallet. These limitations can be adjusted by the contract owner.
3- Sell Cooldown Mechanism: The token has a sell cooldown mechanism that prevents users from selling tokens for a certain duration after their last sell. This feature can be toggled on and off, and the cooldown duration can be adjusted by the contract owner.
4- Dead Block Protection: To prevent users from exploiting the trading launch of the token, a "dead block" protection mechanism is in place. Users buying tokens within a specified number of blocks after trading is enabled will be charged a high tax rate (99%).
5- Automatic Liquidity and Treasury Management: The contract is designed to automatically swap a portion of collected tax into ETH and add liquidity to the trading pair on the decentralized exchange. It also sends a portion of the collected tax to the specified Treasury Wallet in ETH.                                                                                 
*/

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

pragma solidity 0.8.17;

interface DexFactory {
    function createPair(
        address tokenA,
        address tokenB
    ) external returns (address pair);
}

interface DexRouter {
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
        returns (uint256 amountToken, uint256 amountETH, uint256 liquidity);

    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external;
}

contract SCB is ERC20, Ownable {
    struct Tax {
        uint256 TreasuryTax;
        uint256 liquidityTax;
    }

    uint256 private constant _totalSupply = 1e7 * 1e18;

    //Router
    DexRouter public immutable uniswapRouter;
    address public immutable pairAddress;

    //Taxes
    Tax public buyTaxes = Tax(0, 0);
    Tax public sellTaxes = Tax(0, 0);
    Tax public transferTaxes = Tax(0, 0);
    uint256 public totalBuyFees;
    uint256 public totalSellFees;
    uint256 public totalTransferFees;

    //Whitelisting from taxes/maxwallet/txlimit/etc
    mapping(address => bool) private whitelisted;

    //Swapping
    uint256 public swapTokensAtAmount = _totalSupply / 100000; //after 0.001% of total supply, swap them
    bool public swapAndLiquifyEnabled = true;
    bool public isSwapping = false;
    bool public tradingStatus = false;

    //Limitations
    uint256 public maxBuy = _totalSupply;
    uint256 public maxSell = _totalSupply;
    uint256 public maxTx = _totalSupply;
    uint256 public maxWallet = (_totalSupply * 1) / 100;
    mapping(address => uint256) public lastSells;
    uint256 public sellCooldown;
    uint256 public deadBlocks = 3;
    uint256 public startingBlock;
    bool public sellCooldownEnabled = true;

    //Wallets
    address public TreasuryWallet = 0x74Adf47aD22a9C95EE58A6D956FA58924D697E0F;

    //Events
    event TradingStarted(uint256 indexed _startBlock);
    event TreasuryWalletChanged(address indexed _trWallet);
    event MaxBuyUpdated(uint256 indexed _maxBuy);
    event MaxSellUpdated(uint256 indexed _maxSell);
    event MaxTxUpdated(uint256 indexed _maxTx);
    event MaxWalletUpdated(uint256 indexed _maxWallet);
    event BuyFeesUpdated(uint256 indexed _lpFee, uint256 indexed _trFee);
    event SellFeesUpdated(uint256 indexed _lpFee, uint256 indexed _trFee);
    event TransferFeesUpdated(uint256 indexed _lpFee, uint256 indexed _trFee);
    event SwapThresholdUpdated(uint256 indexed _newThreshold);
    event SellCoolDownStatusUpdated(bool indexed _status);
    event SellCoolDownUpdated(uint256 indexed _newAmount);
    event InternalSwapStatusUpdated(bool indexed _status);
    event Whitelist(address indexed _target, bool indexed _status);
    event UpdatedDeadBlocks(uint indexed _deadBlocks);

    constructor() ERC20("Seismic CB", "SCB") {
        uniswapRouter = DexRouter(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
        pairAddress = DexFactory(uniswapRouter.factory()).createPair(
            address(this),
            uniswapRouter.WETH()
        );
        whitelisted[msg.sender] = true;
        whitelisted[address(uniswapRouter)] = true;
        whitelisted[address(this)] = true;
        _mint(msg.sender, _totalSupply);
    }

    function enableTrading() external onlyOwner {
        require(!tradingStatus, "trading is already enabled");
        tradingStatus = true;
        startingBlock = block.number;
        emit TradingStarted(startingBlock);
    }

    function setTreasuryWallet(address _newTreasury) external onlyOwner {
        require(
            _newTreasury != address(0),
            "can not set treasury to dead wallet"
        );
        TreasuryWallet = _newTreasury;
        emit TreasuryWalletChanged(_newTreasury);
    }

    function setMaxBuy(uint256 _mb) external onlyOwner {
        require(
            _mb >= (_totalSupply * 25) / 10000,
            "max buy must be greater than 0.25% of total supply"
        );
        maxBuy = _mb;
        emit MaxBuyUpdated(_mb);
    }

    function setMaxSell(uint256 _ms) external onlyOwner {
        require(
            _ms >= (_totalSupply * 25) / 10000,
            "max sell must be greter than 0.25% of total supply"
        );
        maxSell = _ms;
        emit MaxSellUpdated(_ms);
    }

    function setMaxTx(uint256 _mt) external onlyOwner {
        require(
            _mt >= (_totalSupply * 25) / 10000,
            "max transfer must be greater than 0.25% of total supply"
        );
        maxTx = _mt;
        emit MaxTxUpdated(_mt);
    }

    function setMaxWallet(uint256 _mx) external onlyOwner {
        require(
            _mx > (_totalSupply * 25) / 1000,
            "max wallet must be greater than 0.25% of total supply"
        );
        maxWallet = _mx;
        emit MaxWalletUpdated(_mx);
    }

    function setBuyTaxes(
        uint256 _lpTax,
        uint256 _TreasuryTax
    ) external onlyOwner {
        buyTaxes.TreasuryTax = _TreasuryTax;
        buyTaxes.liquidityTax = _lpTax;
        totalBuyFees = _lpTax + _TreasuryTax;
        require(
            totalBuyFees + totalSellFees <= 22,
            "Can not set buy fees higher than 22%"
        );
        emit BuyFeesUpdated(_lpTax, _TreasuryTax);
    }

    function setSellTaxes(
        uint256 _lpTax,
        uint256 _TreasuryTax
    ) external onlyOwner {
        sellTaxes.TreasuryTax = _TreasuryTax;
        sellTaxes.liquidityTax = _lpTax;
        totalSellFees = _lpTax + _TreasuryTax;
        require(
            totalBuyFees + totalSellFees <= 22,
            "Can not set buy fees higher than 22%"
        );
        emit SellFeesUpdated(_lpTax, _TreasuryTax);
    }

    function setSellCooldown(uint256 _sc) external onlyOwner {
        require(
            _sc >= 30 && _sc <= 10 minutes,
            "Can't set sell cooldown less than 30 seconds and more than 10 minutes"
        );
        sellCooldown = _sc;
        emit SellCoolDownUpdated(_sc);
    }

    function setDeadBlocks(uint256 _db) external onlyOwner {
        require(
            !tradingStatus,
            "can not adjust deadblocks after enabling the trades"
        );
        require(_db <= 10, "can not exceed 10 blocks for anti-bot");
        deadBlocks = _db;
        emit UpdatedDeadBlocks(_db);
    }

    function setTransferFees(
        uint256 _lpTax,
        uint256 _TreasuryTax
    ) external onlyOwner {
        transferTaxes.TreasuryTax = _TreasuryTax;
        transferTaxes.liquidityTax = _lpTax;
        totalTransferFees = _lpTax + _TreasuryTax;
        require(
            totalTransferFees <= 11,
            "Can not set transfer tax higher than 12%"
        );
        emit TransferFeesUpdated(_lpTax, _TreasuryTax);
    }

    function setSwapTokensAtAmount(uint256 _newAmount) external onlyOwner {
        require(
            _newAmount > 0 && _newAmount <= (_totalSupply * 5) / 1000,
            "SCB : Minimum swap amount must be greater than 0 and less than 0.5% of total supply!"
        );
        swapTokensAtAmount = _newAmount;
        emit SwapThresholdUpdated(swapTokensAtAmount);
    }

    function toggleSellCooldown() external onlyOwner {
        sellCooldownEnabled = (sellCooldownEnabled) ? false : true;
        emit SellCoolDownStatusUpdated(sellCooldownEnabled);
    }

    function toggleSwapping() external onlyOwner {
        swapAndLiquifyEnabled = (swapAndLiquifyEnabled) ? false : true;
        emit InternalSwapStatusUpdated(sellCooldownEnabled);
    }

    function setWhitelistStatus(
        address _wallet,
        bool _status
    ) external onlyOwner {
        whitelisted[_wallet] = _status;
        emit Whitelist(_wallet, _status);
    }

    function checkWhitelist(address _wallet) external view returns (bool) {
        return whitelisted[_wallet];
    }

    // this function is reponsible for managing tax, if _from or _to is whitelisted, we simply return _amount and skip all the limitations
    function _takeTax(
        address _from,
        address _to,
        uint256 _amount
    ) internal returns (uint256) {
        if (whitelisted[_from] || whitelisted[_to]) {
            return _amount;
        }
        bool isBuy = false;
        bool isSell = false;
        bool isTransfer = false;
        uint256 totalTax = totalTransferFees;
        if (_to == pairAddress) {
            totalTax = totalSellFees;
            require(
                _amount <= maxSell,
                "SCB : can not sell more than max sell"
            );
            isSell = true;
        } else if (_from == pairAddress) {
            totalTax = totalBuyFees;
            require(_amount <= maxBuy, "SCB : can not buy more than max buy");
            isBuy = true;
        } else {
            require(
                _amount <= maxTx,
                "SCB : can not transfer more than max tx"
            );
            if (tradingStatus) {
                lastSells[_to] = lastSells[_from]; //this makes sure that one can not transfer his tokens to another wallet to bypass sell cooldown
            }
            isTransfer = true;
        }
        // if is buy or sell, firstly dont let trades if is not enabled, secondly, elimniate dead block buyers
        if (isBuy || isSell) {
            require(tradingStatus, "Trading is not enabled yet!");
            if (isBuy) {
                if (startingBlock + deadBlocks >= block.number) {
                    totalTax = 99;
                }
            } else {
                if (sellCooldownEnabled) {
                    require(
                        lastSells[_from] + sellCooldown <= block.timestamp,
                        "sell cooldown"
                    );
                }
                lastSells[_from] = block.timestamp;
            }
        }
        // if is buy or transfer, we have to check max wallet
        if (isBuy || isTransfer) {
            require(
                balanceOf(_to) + _amount <= maxWallet,
                "can not hold more than max wallet"
            );
        }
        uint256 tax = 0;
        if (totalTax > 0) {
            tax = (_amount * totalTax) / 100;
            super._transfer(_from, address(this), tax);
        }
        return (_amount - tax);
    }

    function _transfer(
        address _from,
        address _to,
        uint256 _amount
    ) internal virtual override {
        require(_from != address(0), "transfer from address zero");
        require(_to != address(0), "transfer to address zero");
        uint256 toTransfer = _takeTax(_from, _to, _amount);

        bool canSwap = balanceOf(address(this)) >= swapTokensAtAmount;
        if (
            swapAndLiquifyEnabled &&
            pairAddress == _to &&
            canSwap &&
            !whitelisted[_from] &&
            !whitelisted[_to] &&
            !isSwapping
        ) {
            isSwapping = true;
            internalSwap();
            isSwapping = false;
        }
        super._transfer(_from, _to, toTransfer);
    }

    function internalSwap() internal {
        uint256 taxAmount = balanceOf(address(this));
        if (taxAmount == 0) {
            return;
        }
        //Getting total Fee Percentages And Caclculating Portinos for each tax type
        Tax memory bt = buyTaxes;
        Tax memory st = sellTaxes;
        Tax memory tt = transferTaxes;

        uint256 totalTaxes = totalBuyFees + totalSellFees + totalTransferFees;

        if (totalTaxes == 0) {
            return;
        }

        uint256 totalLPTax = bt.liquidityTax +
            st.liquidityTax +
            tt.liquidityTax;

        //Calculating portions for each type of tax (Treasury, burn, liquidity, rewards)
        uint256 lpPortion = (taxAmount * totalLPTax) / totalTaxes;
        uint256 TreasuryPortion = balanceOf(address(this)) - lpPortion;

        //Add Liquidty taxes to liqudity pool
        if (lpPortion > 0) {
            swapAndLiquify(lpPortion);
        }

        //sending to Treasury wallet
        if (TreasuryPortion > 0) {
            swapToETH(balanceOf(address(this)));
            (bool success, ) = TreasuryWallet.call{
                value: address(this).balance
            }("");
        }
    }

    function swapAndLiquify(uint256 _amount) internal {
        uint256 firstHalf = _amount / 2;
        uint256 otherHalf = _amount - firstHalf;
        uint256 initialETHBalance = address(this).balance;

        //Swapping first half to ETH
        swapToETH(firstHalf);
        uint256 received = address(this).balance - initialETHBalance;
        addLiquidity(otherHalf, received);
    }

    function swapToETH(uint256 _amount) internal {
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = uniswapRouter.WETH();
        _approve(address(this), address(uniswapRouter), _amount);
        uniswapRouter.swapExactTokensForETHSupportingFeeOnTransferTokens(
            _amount,
            0,
            path,
            address(this),
            block.timestamp
        );
    }

    function addLiquidity(uint256 tokenAmount, uint256 ETHAmount) private {
        _approve(address(this), address(uniswapRouter), tokenAmount);
        uniswapRouter.addLiquidityETH{value: ETHAmount}(
            address(this),
            tokenAmount,
            0,
            0,
            0x000000000000000000000000000000000000dEaD,
            block.timestamp
        );
    }

    function withdrawStuckETH() external onlyOwner {
        (bool success, ) = address(msg.sender).call{
            value: address(this).balance
        }("");
        require(success, "transferring ETH failed");
    }

    function withdrawStuckTokens(address erc20_token) external onlyOwner {
        bool success = IERC20(erc20_token).transfer(
            msg.sender,
            IERC20(erc20_token).balanceOf(address(this))
        );
        require(success, "trasfering tokens failed!");
    }

    receive() external payable {}
}