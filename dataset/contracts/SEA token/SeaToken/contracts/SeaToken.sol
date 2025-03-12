//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./BEP20/BEP20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./PancakeSwap/IPancakeV2Factory.sol";
import "./PancakeSwap/IPancakeV2Pair.sol";
import "./PancakeSwap/IPancakeV2Router01.sol";
import "./PancakeSwap/IPancakeV2Router02.sol";


contract SeaToken is BEP20, Ownable {
    using SafeMath for uint;

    address public constant CHARITY_WALLET = 0xaf72Fb3310561C0826fdF852c05bC50BF54989cd;
    address public constant ADMIN_WALLET = 0x69Ba7E86bbB074Cd5f72693DEb6ADc508D83A6bF;

    uint public constant TOTAL_SUPPLY = 2*(10**8); // 200M
    address public constant BURN_ADDRESS = 0x000000000000000000000000000000000000dEaD;
    uint public constant BURN_AMOUNT = 8 * (10 ** 25); // 80M * 10**18 (decimals)

    uint public CHARITY_WALLET_TAX_BP = 200; // 2%
    uint public LP_LOCK_BP = 100; // 1%
    uint public DISTRIBUTION_BP = 200; // 2%
    uint public PERCENTAGE_MULTIPLIER = 10000;

    bool private isBurnEventOver = false; // once burn event is over, this value will be set to true and tax on each tx will start

    mapping(address => uint) public distributionDebt;
    uint public accSeaPerShare = 0;
    uint public constant MINIMUM_DISTRIBUTION_VALUE = 10 ** 8;


    IPancakeV2Router02 public immutable pancakeV2Router;
    address public immutable pancakeV2Pair;

    uint256 public TotalBurnedLpTokens;

    bool public inSwapAndLiquify;

    event Burned(uint amount);

    event SwapLiquifyAndBurn(
        uint256 tokensSwapped,
        uint256 ethReceived,
        uint256 tokensIntoLiqudity
    );

    modifier lockTheSwap {
        inSwapAndLiquify = true;
        _;
        inSwapAndLiquify = false;
    }


    constructor() BEP20("Sea Token", "SEA") {
        uint amount = TOTAL_SUPPLY.mul(10**decimals()).mul(10000).div(PERCENTAGE_MULTIPLIER); // 100% to ADMIN_WALLET

        _totalSupply = _totalSupply.add(amount);
        _balances[ADMIN_WALLET] = _balances[ADMIN_WALLET].add(amount);

         IPancakeV2Router02 _pancakeV2Router = IPancakeV2Router02(0x10ED43C718714eb63d5aA57B78B54704E256024E); // Mainnet
//        IPancakeV2Router02 _pancakeV2Router = IPancakeV2Router02(0xD99D1c33F9fC3444f8101754aBC46c52416550D1); // testnet // https://twitter.com/PancakeSwap/status/1369547285160370182

        // Create a uniswap pair for this new token
        pancakeV2Pair = IPancakeV2Factory(_pancakeV2Router.factory())
        .createPair(address(this), _pancakeV2Router.WETH());

        // set the rest of the contract variables
        pancakeV2Router = _pancakeV2Router;

        transferOwnership(ADMIN_WALLET); // Make admin owner

    }

    function swapLiquifyAndBurn(uint256 amount) private lockTheSwap {
        // split the contract balance into halves
        uint256 half = amount.div(2);
        uint256 otherHalf = amount.sub(half);

        // capture the contract's current ETH balance.
        // this is so that we can capture exactly the amount of ETH that the
        // swap creates, and not make the liquidity event include any ETH that
        // has been manually sent to the contract
        uint256 initialBalance = address(this).balance;

        // swap tokens for ETH
        swapTokensForEth(half); // <- this breaks the ETH -> SEA swap when swap+liquify is triggered

        // how much ETH did we just swap into?
        uint256 newBalance = address(this).balance.sub(initialBalance);

        // add liquidity to uniswap
        addLiquidity(otherHalf, newBalance);
        // Burn received LP tokens
        burnLpTokens();

        emit SwapLiquifyAndBurn(half, newBalance, otherHalf);
    }

    function swapTokensForEth(uint256 tokenAmount) private {
        // generate the uniswap pair path of token -> weth
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = pancakeV2Router.WETH();

        _approve(address(this), address(pancakeV2Router), tokenAmount);

        // make the swap
        pancakeV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0, // accept any amount of ETH
            path,
            address(this),
            block.timestamp
        );
    }

    function addLiquidity(uint256 tokenAmount, uint256 ethAmount) private {
        // approve token transfer to cover all possible scenarios
        _approve(address(this), address(pancakeV2Router), tokenAmount);

        // add the liquidity
        pancakeV2Router.addLiquidityETH{value: ethAmount}(
            address(this),
            tokenAmount,
            0, // slippage is unavoidable
            0, // slippage is unavoidable
            address(this),
            block.timestamp
        );
    }

    function burnLpTokens() private {
        IPancakeV2Pair _token = IPancakeV2Pair(pancakeV2Pair);
        uint256 amount = _token.balanceOf(address(this));
        TotalBurnedLpTokens = TotalBurnedLpTokens.add(amount);
        _token.transfer(BURN_ADDRESS, amount);
    }

    function calcPercent(uint amount, uint percentBP) internal view returns (uint){
        return amount.mul(percentBP).div(PERCENTAGE_MULTIPLIER);
    }

    function sync(address user) internal {
        // for first user this will result in 0
        _balances[user] = balanceOf(user);
        distributionDebt[user] = accSeaPerShare;
    }

    /**
     * @dev Moves tokens `amount` from `sender` to `recipient`.
     *
     * This is internal function is equivalent to {transfer}, and can be used to
     * e.g. implement automatic token fees, slashing mechanisms, etc.
     *
     * Emits a {Transfer} event.
     *
     * Requirements:
     *
     * - `sender` cannot be the zero address.
     * - `recipient` cannot be the zero address.
     * - `sender` must have a balance of at least `amount`.
     */
    function _transfer(address sender, address recipient, uint256 amount) internal override {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");

        sync(sender);
        sync(recipient);

        uint256 senderBalance = _balances[sender];
        require(senderBalance >= amount, "ERC20: transfer amount exceeds balance");

        // Start taxing after Burn event is done and liquidity pool is ready
        if (isBurnEventOver &&
            recipient != BURN_ADDRESS &&
            !inSwapAndLiquify &&
            sender != pancakeV2Pair &&
            sender != owner()
        ) {
            _transferWithTax(sender, recipient, amount);
        } else {
            _transferWithoutTax(sender, recipient, amount);
        }
    }

    function _transferWithoutTax(address sender, address recipient, uint256 amount) internal {
        _balances[sender] = _balances[sender].sub(amount);
        _balances[recipient] = _balances[recipient].add(amount);
        emit Transfer(sender, recipient, amount);
    }

    function _transferWithTax(address sender, address recipient, uint256 amount) internal {
        uint charityTax = calcPercent(amount, CHARITY_WALLET_TAX_BP);
        uint lpLockTax = calcPercent(amount, LP_LOCK_BP);
        uint distributionTax = calcPercent(amount, DISTRIBUTION_BP);

        _balances[sender] = _balances[sender].sub(amount);

        // send 2% to charity wallet
        _balances[CHARITY_WALLET] = _balances[CHARITY_WALLET].add(charityTax);
        // lock 1% in liquidity
        _balances[address(this)] = _balances[address(this)].add(lpLockTax); // give lp tax to self and then swap, liquify and burn
        swapLiquifyAndBurn(lpLockTax);
        // distribute 2% to all other holders
        accSeaPerShare = accSeaPerShare.add(distributionTax.div(totalSupply().div(MINIMUM_DISTRIBUTION_VALUE)));

        uint amountToRecipient = amount.sub(charityTax).sub(lpLockTax).sub(distributionTax);

        _balances[recipient] = _balances[recipient].add(amountToRecipient);

        emit Transfer(sender, recipient, amountToRecipient);
        emit Transfer(sender, CHARITY_WALLET, charityTax);
    }

    /**
     * @dev See {IERC20-balanceOf}.
     */
    function balanceOf(address account) public view virtual override returns (uint256) {
        return _balances[account].add(accSeaPerShare.sub(distributionDebt[account]).mul(_balances[account].div(MINIMUM_DISTRIBUTION_VALUE)));
    }

    function burn() public onlyOwner {
        require(!isBurnEventOver);
        _transfer(msg.sender, BURN_ADDRESS, BURN_AMOUNT);
        isBurnEventOver = true;
        emit Burned(BURN_AMOUNT);
    }

    //to receive ETH from uniswapV2Router when swapping
    receive() external payable {}
}
