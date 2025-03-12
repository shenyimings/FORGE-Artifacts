// @SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import './interfaces/IUniswapV2Router02.sol';
import './interfaces/IUniswapV2Factory.sol';
import './utils/AutoWithdrawFarm.sol';
import './utils/Address.sol';

contract Wagyu is AutoWithdrawFarm {
    mapping(address => uint256) private _countSold;
    mapping(address => uint256) private _countStart;
    uint256 private _minSwap;

    // PancakeSwap (Testnet): 0xD99D1c33F9fC3444f8101754aBC46c52416550D1
    // Pancakeswap v2 (Mainnet): 0x10ED43C718714eb63d5aA57B78B54704E256024E
    IUniswapV2Router02 public constant router =
        IUniswapV2Router02(0x10ED43C718714eb63d5aA57B78B54704E256024E);
    address public constant charityAddress =
        address(0x8B99F3660622e21f2910ECCA7fBe51d654a1517D);
    address public constant dead =
        address(0x000000000000000000000000000000000000dEaD);
    address public immutable pair;
    uint256 public whaleTime = 6 hours;
    uint8 public whaleModifier = 20;
    uint16 public whalePercent = 945;
    uint256 public buybackThreshold = 5 ether;
    uint256 public pendingBuyback;
    uint256 public totalDonated;

    constructor() BEP20('SteakCoin', 'WAGYU') AutoWithdrawFarm(15) {
        _minSwap = 100_000 * 10**_decimals;

        address _pair = pair = IUniswapV2Factory(router.factory()).createPair(
            address(this),
            router.WETH()
        );

        _nonReflectable[_pair] = true;
        _nonReflectable[address(router)] = true;
        _nonTaxableSend[address(_pair)] = true;
        setTaxable(address(this), false, false);
        setTaxable(msg.sender, false, false);

        _mint(msg.sender, 10_000_000_000 * (10**_decimals));
    }

    receive() external payable {
        if (msg.sender != address(router)) {
            payable(manager).transfer(msg.value);
        }
    }

    function setBuybackThreshold(uint256 _buybackThreshold)
        external
        onlyManager
    {
        require(
            _buybackThreshold >= 1_000_000 gwei,
            'Wagyu: threshold cannot be lower than 0.01'
        );

        buybackThreshold = _buybackThreshold;

        emit SetBuybackThreshold(_buybackThreshold);
    }

    function setWhaleTime(uint256 _whaleTime) external onlyManager {
        require(
            _whaleTime <= 24 hours,
            'Wagyu: whale time cannot be longer than 24 hours'
        );

        whaleTime = _whaleTime;

        emit SetWhaleTime(whaleTime);
    }

    function setWhaleModifier(uint8 _whaleModifier) external onlyManager {
        require(
            _whaleModifier >= 10,
            'Wagyu: whale modifier cannot be lower than 1x'
        );

        whaleModifier = _whaleModifier;

        emit SetWhaleModifier(whaleModifier);
    }

    function setWhalePercent(uint16 _whalePercent) external onlyManager {
        require(
            _whalePercent > 750,
            'Wagyu: whale percent cannot be lower than 0.075%'
        );

        whalePercent = _whalePercent;

        emit SetWhalePercent(whalePercent);
    }

    function _transfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal override {
        if (!_isNonTaxable(sender, recipient)) {
            // Anti-whale [percentage of total supply]
            require(
                amount < (_totalSupply * whalePercent) / 100_000,
                'Wagyu: bad whale'
            );

            // Reset sold count if it's been longer than the whale time
            if (_countStart[sender] + whaleTime > block.timestamp) {
                _countStart[sender] = block.timestamp;
                _countSold[sender] = 0;
            }

            _countSold[sender] += amount;

            // Anti-whale [total sale over whaleTime]
            require(
                _countSold[sender] <=
                    (_totalSupply * whalePercent * 20) / 1_000_000,
                'Wagyu: bad whale'
            );
        }

        super._transfer(sender, recipient, amount);

        // Should not do any swapping when sending to or from the pair
        if (sender == address(pair) || recipient == address(pair)) {
            return;
        }

        if (pendingBuyback >= buybackThreshold) {
            _buyback();
        } else if (_balances[address(this)] >= _minSwap) {
            _swapAndDonate();
        }
    }

    function _distributeTax(uint256 amount) internal override {
        // Add tax tokens to contract balance, as it will swap and
        // distribute them after they surpass the _minSwap variable
        _balances[address(this)] += amount;
    }

    function _swapAndDonate() internal {
        // Get initial balances to figure out how much was actually swapped
        uint256 balance = address(this).balance;
        uint256 amount = balanceOf(address(this));
        _approve(address(this), address(router), amount);
        router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            amount,
            0,
            _swapPathWeth(),
            address(this),
            block.timestamp
        );

        // Calculate shares, reflect and donate to charity
        uint256 sold = address(this).balance - balance;
        uint256 holderShare = (sold * 8) / 15;
        uint256 charityShare = sold / 15;
        pendingBuyback += sold - holderShare - charityShare;

        _reflect(holderShare);
        payable(charityAddress).transfer(charityShare);

        emit CharityDonation(amount);
    }

    function _buyback() internal {
        // Get initial balances to figure out how much was actually swapped
        uint256 tokens = _balances[address(this)];
        uint256 balance = address(this).balance;
        // Only buyback half, as the other half is used for liquidity
        uint256 buyback = pendingBuyback / 2;
        uint256 deadBal = _balances[dead];
        router.swapExactETHForTokensSupportingFeeOnTransferTokens{
            value: buyback
        }(0, _swapPathWagyu(), dead, block.timestamp);

        // Move swapped funds from dead to contract
        uint256 swapped = _balances[dead] - deadBal;
        _balances[address(this)] += swapped;
        _balances[dead] -= swapped;

        // Update pending buyback and balance to account for dust
        pendingBuyback = balance - address(this).balance;
        balance = address(this).balance;

        // Add liquidity with half of the tokens, and burn the rest
        uint256 burn = (_balances[address(this)] - tokens);
        uint256 liquidity = burn / 2;
        burn -= liquidity;

        _burn(address(this), burn);
        _addLiquidity(liquidity, pendingBuyback);
        // Update pending buyback to account for dust
        pendingBuyback = balance - address(this).balance;

        emit Buyback(buyback, swapped, burn);
    }

    function _addLiquidity(uint256 tokens, uint256 ethAmount) internal {
        _approve(address(this), address(router), tokens);
        router.addLiquidityETH{value: ethAmount}(
            address(this),
            tokens,
            0,
            0,
            manager,
            block.timestamp
        );
    }

    function _swapPathWeth() internal view returns (address[] memory path) {
        path = new address[](2);
        path[0] = address(this);
        path[1] = router.WETH();
    }

    function _swapPathWagyu() internal view returns (address[] memory path) {
        path = new address[](2);
        path[0] = router.WETH();
        path[1] = address(this);
    }

    event CharityDonation(uint256 amount);
    event SetBuybackThreshold(uint256 amount);
    event SetWhaleTime(uint256 whaleTime);
    event SetWhalePercent(uint16 whalePercent);
    event SetWhaleModifier(uint8 whaleModifier);
    event Buyback(uint256 ethAmount, uint256 wagyuAmount, uint256 burned);
}
