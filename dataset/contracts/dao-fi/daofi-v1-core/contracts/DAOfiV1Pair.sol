// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity =0.7.4;
pragma experimental ABIEncoderV2;

import '@daofi/bancor/solidity/contracts/converter/interfaces/IBancorFormula.sol';
import 'hardhat/console.sol';
import './interfaces/IDAOfiV1Factory.sol';
import './interfaces/IDAOfiV1Pair.sol';
import './interfaces/IERC20.sol';
import './libraries/SafeMath.sol';

contract DAOfiV1Pair is IDAOfiV1Pair {
    using SafeMath for *;

    uint32 private constant SLOPE_DENOM = 1000000;
    uint32 private constant MAX_N = 1;
    uint8 private constant INITIAL_DECIMALS = 4;
    uint8 private constant INTERNAL_DECIMALS = 8;
    uint8 public constant MAX_FEE = 10; // 1%
    uint8 public constant override PLATFORM_FEE = 1; // 0.1%
    address public constant PLATFORM = 0x31b2d5f134De0A737360693Ed5D5Bd42b705bCa2;
    bytes4 private constant SELECTOR = bytes4(keccak256(bytes('transfer(address,uint256)')));
    address public override factory;
    /**
    * @dev Reserve ratio, represented in ppm, 1-1000000
    * 1/3 corresponds to y = slope * x^2
    * 1/2 corresponds to y = slope * x
    * 2/3 corresponds to y = slope * x^1/2
    *
    * Note: slope is determined by initial supply and we are specifically
    * restricting reserveRatio <= MAX_WEIGHT / 2 to force integer exponents >= 1
    */
    uint32 public override reserveRatio;
    // slope = slopeNumerator / SLOPE_DENOM, this value is baked into the equations by the initial supply
    uint32 public override slopeNumerator;
    uint32 public override n;
    uint32 public override fee;
    address public override baseToken;
    address public override quoteToken;
    address public override pairOwner;
    uint256 public override supply; // track base tokens issued

    address private router;
    uint256 private reserveBase;       // uses single storage slot, accessible via getReserves
    uint256 private reserveQuote;      // uses single storage slot, accessible via getReserves
    uint256 private feesBaseOwner;
    uint256 private feesQuoteOwner;
    uint256 private feesBasePlatform;
    uint256 private feesQuotePlatform;
    bool private deposited = false;
    uint private unlocked = 1;

    /**
    * @dev Create the contract and set initial values of slope and exponent such that
    * the default price curve is y = mx^n, where m = 1 and n = 1.
    */
    constructor() {
        factory = msg.sender;
        reserveRatio = 500000; // max weight / 2 for default curve y = x
        slopeNumerator = SLOPE_DENOM;
        n = 1;
        fee = 0;
        supply = 0;
    }

    /**
    * @dev Used to prevent reentrancy attack
    */
    modifier lock() {
        require(unlocked == 1, 'DAOfiV1: LOCKED');
        unlocked = 0;
        _;
        unlocked = 1;
    }

    /**
    * @dev Helper function to safely call ERC20 transfer
    *
    * @param token address of token
    * @param to recipient address of transfer
    * @param value token value to transfer
    */
    function _safeTransfer(address token, address to, uint256 value) private {
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(SELECTOR, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'DAOfiV1: TRANSFER_FAILED');
    }

    /**
    * @dev Wrapper function to retrieve the bancor formula address from the factory
    * and return the contract interface of the formula.
    *
    * @return IBancorFormula
    */
    function _getFormula() private view returns (IBancorFormula) {
        return IBancorFormula(IDAOfiV1Factory(factory).formula());
    }

    /**
    * @dev Convert token amounts to and from internal decimal places
    *
    * @param token address for the token of the amount being converted
    * @param amount the amount of token being converted
    * @param resolution the number of decimal places to or from
    * @param to boolean to indicate conversion to or from resolution
    *
    * @return converted amount after conversion
    */
    function _convert(address token, uint256 amount, uint8 resolution, bool to) private view returns (uint256 converted) {
        uint8 decimals = IERC20(token).decimals();
        uint256 diff = 0;
        uint256 factor = 0;
        converted = amount;
        if (decimals > resolution) {
            diff = uint256(decimals.sub(resolution));
            factor = 10 ** diff;
            if (to && amount >= factor) {
                converted = amount.div(factor);
            } else if (!to) {
                converted = amount.mul(factor);
            }
        } else if (decimals < resolution) {
            diff = uint256(resolution.sub(decimals));
            factor = 10 ** diff;
            if (to) {
                converted = amount.mul(factor);
            } else if (!to && amount >= factor) {
                converted = amount.div(factor);
            }
        }
    }

    /**
    * @dev Get the base and quote reserves, as a tuple
    *
    * @return _reserveBase
    * @return _reserveQuote
    */
    function getReserves() public override view returns (uint256 _reserveBase, uint256 _reserveQuote) {
        _reserveBase = reserveBase;
        _reserveQuote = reserveQuote;
    }

    /**
    * @dev Get the accumlated base and quote fees for the platform, as a tuple
    *
    * @return feesBase
    * @return feesQuote
    */
    function getPlatformFees() public override view returns (uint256 feesBase, uint256 feesQuote) {
        feesBase = feesBasePlatform;
        feesQuote = feesQuotePlatform;
    }

    /**
    * @dev Get the accumlated base and quote fees for the owner, as a tuple
    *
    * @return feesBase
    * @return feesQuote
    */
    function getOwnerFees() public override view returns (uint256 feesBase, uint256 feesQuote) {
        feesBase = feesBaseOwner;
        feesQuote = feesQuoteOwner;
    }

    /**
    * @dev Initialize the pair with a set of tokens, slope, exponent and fee.
    * This function is called immediately after a pair is created by the periphery.
    *
    * @param _router address of the router (periphery contract)
    * @param _baseToken token address of the base token
    * @param _quoteToken token address of the quote token
    * @param _pairOwner address of the pair owner
    * @param _slopeNumerator value between 1 - 1000 which determines the curve slope (slopeNumerator / SLOPE_DENOM)
    * @param _n value between 1 - 3 which determines the reserve ratio of the curve (r = 1 / (n + 1))
    * @param _fee value between 0 - 10 which determines swap fee
    */
    function initialize(
        address _router,
        address _baseToken,
        address _quoteToken,
        address _pairOwner,
        uint32 _slopeNumerator,
        uint32 _n,
        uint32 _fee
    ) external override {
        require(msg.sender == factory, 'DAOfiV1: FORBIDDEN');
        require(_slopeNumerator > 0 && _slopeNumerator <= SLOPE_DENOM, 'DAOfiV1: INVALID_SLOPE_NUMERATOR');
        require(_n > 0 && _n <= MAX_N, 'DAOfiV1: INVALID_N');
        require(_fee <= MAX_FEE, 'DAOfiV1: INVALID_FEE');
        router = _router;
        baseToken = _baseToken;
        quoteToken = _quoteToken;
        pairOwner = _pairOwner;
        slopeNumerator = _slopeNumerator;
        n = _n;
        fee = _fee;
        supply = 0;
        reserveRatio = uint32(
            _getFormula().MAX_WEIGHT().div(n + 1)
        );  // (1 / (n + 1)) * MAX_WEIGHT
    }

    /**
    * @dev Transfer ownership of the pair's reserves and owner fees
    */
    function setPairOwner(address _nextOwner) external override {
        require(msg.sender == pairOwner, 'DAOfiV1: FORBIDDEN_PAIR_OWNER');
        pairOwner = _nextOwner;
    }

    /**
    * @dev Used to initialize a pair's reserves, called via periphery addLiquidity function only.
    * This function uses the amount of quote reserve to determine an initial supply of base,
    * which is returned from the base reserve.
    *
    * @param to address of the initial supply recipient
    *
    * @return amountBaseOut initial supply amount for the recipient
    */
    function deposit(address to) external override lock returns (uint256 amountBaseOut) {
        require(msg.sender == router, 'DAOfiV1: FORBIDDEN_DEPOSIT');
        require(deposited == false, 'DAOfiV1: DOUBLE_DEPOSIT');
        reserveBase = IERC20(baseToken).balanceOf(address(this));
        reserveQuote = IERC20(quoteToken).balanceOf(address(this));
        // this function is locked and the contract can not reset reserves
        deposited = true;
        if (reserveQuote > 0) {
            // set initial supply from reserveQuote
            supply = amountBaseOut = getBaseOut(reserveQuote);
            if (amountBaseOut > 0) {
                _safeTransfer(baseToken, to, amountBaseOut);
                reserveBase = reserveBase.sub(amountBaseOut);
            }
        }
        emit Deposit(msg.sender, reserveBase, reserveQuote, amountBaseOut, to);
    }

    /**
    * @dev Withdraw function will remove all funds from the contract, minus fees attributed to the platform.
    * once this function is called, the pair is effectively closed.
    *
    * @param to address of the withdrawal recipient
    *
    * @return amountBase amount of base token withdrawn
    * @return amountQuote amount of quote token withdrawn
    */
    function withdraw(address to) external override lock returns (uint256 amountBase, uint256 amountQuote) {
        require(msg.sender == router, 'DAOfiV1: FORBIDDEN_WITHDRAW');
        require(deposited, 'DAOfiV1: UNINITIALIZED');
        amountBase = IERC20(baseToken).balanceOf(address(this)).sub(feesBasePlatform);
        amountQuote = IERC20(quoteToken).balanceOf(address(this)).sub(feesQuotePlatform);
        _safeTransfer(baseToken, to, amountBase);
        _safeTransfer(quoteToken, to, amountQuote);
        reserveBase = feesBaseOwner = 0;
        reserveQuote = feesQuoteOwner = 0;
        emit Withdraw(msg.sender, amountBase, amountQuote, to);
    }

    /**
    * @dev Platform-only function to remove fees attributed to platform.
    * Fees for the platform are reset to 0 once called.
    *
    * @param to address of the fee recipient
    *
    * @return amountBase amount of base token withdrawn
    * @return amountQuote amount of quote token withdrawn
    */
    function withdrawPlatformFees(address to) external override lock returns (uint256 amountBase, uint256 amountQuote) {
        require(msg.sender == PLATFORM, 'DAOfiV1: FORBIDDEN_WITHDRAW');
        require(deposited, 'DAOfiV1: UNINITIALIZED');
        amountBase = feesBasePlatform;
        amountQuote = feesQuotePlatform;
        _safeTransfer(baseToken, to, amountBase);
        _safeTransfer(quoteToken, to, amountQuote);
        feesBasePlatform = 0;
        feesQuotePlatform = 0;
        emit WithdrawFees(msg.sender, amountBase, amountQuote, to);
    }

    /**
    * @dev Given token in, token out, amount in, amount out, verify the amount out is correct and send to recipient.
    *
    * @param tokenIn address of input token, either base or quote
    * @param tokenOut address of output token, either base or quote, depending on input token
    * @param amountIn amount of token in
    * @param amountOut desired amount of token out
    * @param to address of token out recipient
    */
    function swap(address tokenIn, address tokenOut, uint256 amountIn, uint256 amountOut, address to) external override lock {
        require(deposited, 'DAOfiV1: UNINITIALIZED_SWAP');
        require(
            (tokenIn == baseToken && tokenOut == quoteToken) || (tokenOut == baseToken && tokenIn == quoteToken),
            'DAOfiV1: INCORRECT_TOKENS'
        );
        require(to != baseToken && to != quoteToken, 'DAOfiV1: INVALID_TO');
        require(amountOut > 0 && amountIn > 0, 'DAOfiV1: INSUFFICIENT_IO_AMOUNT');
        _safeTransfer(tokenOut, to, amountOut); // optimistically transfer tokens
        uint256 balanceIn;
        uint256 reserveIn;
        if (tokenIn == baseToken) {
            reserveIn = reserveBase;
            balanceIn = IERC20(baseToken).balanceOf(address(this))
                .sub(feesBaseOwner)
                .sub(feesBasePlatform);
        } else if (tokenIn == quoteToken) {
            reserveIn = reserveQuote;
            balanceIn = IERC20(quoteToken).balanceOf(address(this))
                .sub(feesQuoteOwner)
                .sub(feesQuotePlatform);
        }
        uint256 surplus = balanceIn > reserveIn ? balanceIn - reserveIn : 0;
        require(amountIn <= surplus, 'DAOfiV1: INCORRECT_INPUT_AMOUNT');
        // account for owner and platform fees separately
        uint256 amountInSubOwnerFee = amountIn.mul(1000 - fee) / 1000;
        uint256 amountInSubPlatformFee = amountIn.mul(1000 - PLATFORM_FEE) / 1000;
        uint256 amountInSubFees = amountIn.mul(1000 - (fee + PLATFORM_FEE)) / 1000;
        // Check that inputs equal output
        // handle quote to base
        if (tokenOut == baseToken) {
            require(getBaseOut(amountInSubFees) == amountOut, 'DAOfiV1: INVALID_BASE_OUTPUT');
            require(amountOut <= reserveBase, 'DAOfiV1: INSUFFICIENT_BASE_RESERVE');
            supply = supply.add(amountOut);
            reserveQuote = reserveQuote.add(amountInSubFees);
            reserveBase = reserveBase.sub(amountOut);
            feesQuoteOwner = feesQuoteOwner.add(amountIn).sub(amountInSubOwnerFee);
            feesQuotePlatform = feesQuotePlatform.add(amountIn).sub(amountInSubPlatformFee);
        } else if (tokenOut == quoteToken) {
            require(getQuoteOut(amountInSubFees) == amountOut, 'DAOfiV1: INVALID_QUOTE_OUTPUT');
            require(amountOut <= reserveQuote, 'DAOfiV1: INSUFFICIENT_QUOTE_RESERVE');
            supply = supply.sub(amountInSubFees);
            reserveQuote = reserveQuote.sub(amountOut);
            reserveBase = reserveBase.add(amountInSubFees);
            feesBaseOwner = feesBaseOwner.add(amountIn).sub(amountInSubOwnerFee);
            feesBasePlatform = feesBasePlatform.add(amountIn).sub(amountInSubPlatformFee);
        }
        emit Swap(address(this), msg.sender, tokenIn, tokenOut, amountIn, amountOut, to);
    }

    /**
    * @dev Returns the price of 1 base token, in quote
    *
    * @return price
    */
    function basePrice() public view override returns (uint256 price) {
        require(deposited, 'DAOfiV1: UNINITIALIZED_BASE_PRICE');
        price = getQuoteOut(10 ** IERC20(baseToken).decimals());
    }

    /**
    * @dev Returns the price of 1 quote token, in base
    *
    * @return price
    */
    function quotePrice() public view override returns (uint256 price) {
        require(deposited, 'DAOfiV1: UNINITIALIZED_QUOTE_PRICE');
        price = getBaseOut(10 ** IERC20(quoteToken).decimals());
    }

    /**
    * @dev Given the base token supply, quote reserve, reserve ratio and a quote token input amount,
    * calculate the amount of base token returned
    *
    * Formula:
    * base out = supply * ((1 + amountQuoteIn / reserveQuote) ^ (reserveRatio / 1000000) - 1)
    *
    * @param amountQuoteIn quote token input amount
    *
    * @return amountBaseOut amount of base token returned
    */
    function getBaseOut(uint256 amountQuoteIn) public view override returns (uint256 amountBaseOut) {
        require(deposited, 'DAOfiV1Pair: UNINITIALIZED');
        // Cases for 0 supply,with differing examples between research, bancor v1, bancor v2
        // given quote reserve = b, reserve ratio = r, slope = m, find supply s

        // s = (b / rm)^r
        // https://blog.relevant.community/bonding-curves-in-depth-intuition-parametrization-d3905a681e0a

        if (supply == 0) {
            // Handle amounts as internal decimals then convert back to token decimals before returning
            amountQuoteIn = _convert(quoteToken, amountQuoteIn, INITIAL_DECIMALS, true);
            (uint256 result, uint8 precision) = _getFormula().power(
                amountQuoteIn.mul(SLOPE_DENOM).mul(_getFormula().MAX_WEIGHT()),
                slopeNumerator.mul(reserveRatio),
                reserveRatio,
                _getFormula().MAX_WEIGHT()
            );
            amountBaseOut = _convert(
                baseToken,
                result >> precision,
                INITIAL_DECIMALS >> 1,
                false
            );
        } else {
            amountQuoteIn = _convert(quoteToken, amountQuoteIn, INTERNAL_DECIMALS, true);
            amountBaseOut = _convert(
                baseToken,
                _getFormula().purchaseTargetAmount(
                    _convert(baseToken, supply, INTERNAL_DECIMALS, true),
                    _convert(quoteToken, reserveQuote, INTERNAL_DECIMALS, true),
                    reserveRatio,
                    amountQuoteIn
                ),
                INTERNAL_DECIMALS,
                false
            );
        }
    }

    /**
    * @dev Given the base token supply, quote reserve, reserve ratio and a base token input amount,
    * calculate the amount of quote token returned
    *
    * Formula:
    * quote out = reserveQuote * (1 - (1 - amountBaseIn / supply) ^ (1000000 / reserveRatio)))
    *
    * @param amountBaseIn base token input amount
    *
    * @return amountQuoteOut amount of quote token returned
    */
    function getQuoteOut(uint256 amountBaseIn) public view override returns (uint256 amountQuoteOut) {
        require(deposited, 'DAOfiV1Pair: UNINITIALIZED');
        if (amountBaseIn >= supply) {
            amountQuoteOut = reserveQuote;
        } else {
            amountBaseIn = _convert(baseToken, amountBaseIn, INTERNAL_DECIMALS, true);
            amountQuoteOut = _convert(
                quoteToken,
                _getFormula().saleTargetAmount(
                    _convert(baseToken, supply, INTERNAL_DECIMALS, true),
                    _convert(quoteToken, reserveQuote, INTERNAL_DECIMALS, true),
                    reserveRatio,
                    amountBaseIn
                ),
                INTERNAL_DECIMALS,
                false
            );
        }
    }
}
