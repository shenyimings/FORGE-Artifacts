// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.13;

import "hardhat/console.sol";

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IWETH.sol";

import "../interface/ICurvePool.sol";
import "../interface/ISCompVault.sol";

contract OneClick is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    IWETH public wTokenInterface;
    address private wToken;

    IUniswapV2Router02 private router;
    address private routerAddress;

    IUniswapV2Factory private factory;
    address private factoryAddress;

    uint256 private constant minAmount = 1000;
    uint256 public constant maxInt = 2 ** 256 - 1;

    uint256 public constant oneClickMax = 10000; // 100%
    uint256 public oneClickFee; // 1 = 0.01% ; 10 = 0.1% ; 100 = 1% ; 1000 = 10% ; 10000 = 100%
    address public oneClickFeeAddress;
    address public timeLockController;

    /*
     * @notice Fallback for wToken
     */
    receive() external payable {
        assert(msg.sender == wToken);
    }

    event NewOneClickIn(
        address indexed TokenIn,
        address indexed poolAddress,
        uint256 amountIn,
        uint256 lpAmount,
        address indexed user
    );

    event NewOneClickOut(
        address indexed TokenOut,
        address indexed poolAddress,
        uint256 amountOut,
        uint256[] TokenOutAmount,
        address indexed user
    );

    // Owner recovers token
    event TokenRecovery(address indexed token, uint256 amount);

    /*
     * @notice Constructor
     * @param _router: address of the Router
     * @param _factory: address of the Factory
     * @param wToken address: address of the wToken contract
     * @param _oneClickFee: fee of the oneClick
     */
    constructor(
        address _router,
        address _factory,
        address _wToken,
        uint256 _oneClickFee,
        address _oneClickFeeAddress
    ) {
        routerAddress = _router;
        router = IUniswapV2Router02(_router);
        factoryAddress = _factory;
        factory = IUniswapV2Factory(_factory);
        wToken = _wToken;
        wTokenInterface = IWETH(_wToken);
        oneClickFee = _oneClickFee;
        oneClickFeeAddress = _oneClickFeeAddress;
    }

    // External Functions

    /*
     * @notice OneClick a token in (e.g. token/other token)
     * @param _route: The token in and routing for swap (if needed)
     * @param _poolAddress: Curve pool address
     * @param _tokenAddress: Curve token address
     * @param _poolTokens: Curve tokens in the pool
     * @param _vault: StablecompVault address
     * @param _oneToken: invest in all tokens or in a one of specified index
     * @param _indexIn: index of the specified to invest
     * @param _slippage: slippage for the deposit
     */
    function OneClickInETH(
        address[][] memory _route,
        address _poolAddress,
        address _tokenAddress,
        address[] memory _poolTokens,
        address _vault,
        bool _oneToken,
        uint256 _indexIn,
        uint256 _slippage
    ) external payable nonReentrant {
        require(msg.value >= minAmount, "One Click: too small input amount");
        require(
            _poolTokens.length <= 4 && _poolTokens.length >= 2,
            "OneClick: pool size range is: min 2, max 4"
        );

        wTokenInterface.deposit{value: msg.value}();

        uint256 lpAmount = _OneClickIn(
            _route,
            _poolAddress,
            _tokenAddress,
            _poolTokens,
            _vault,
            msg.value,
            _oneToken,
            _indexIn,
            _slippage
        );

        emit NewOneClickIn(
            address(0x0000000000000000000000000000000000000000),
            _poolAddress,
            msg.value,
            lpAmount,
            msg.sender
        );
    }

    /*
     * @notice OneClick a token in (e.g. token/other token)
     * @param _route: The token in and routing for swap (if needed)
     * @param _poolAddress: Curve pool address
     * @param _tokenAddress: Curve token address
     * @param _poolTokens: Curve tokens in the pool
     * @param _vault: StablecompVault address
     * @param _amountIn: amount of token to swap
     * @param _oneToken: invest in all tokens or in a one of specified index
     * @param _indexIn: index of the specified to invest
     * @param _slippage: slippage for the deposit
     */
    function OneClickIn(
        address[][] memory _route,
        address _poolAddress,
        address _tokenAddress,
        address[] memory _poolTokens,
        address _vault,
        uint256 _amountIn,
        bool _oneToken,
        uint256 _indexIn,
        uint256 _slippage
    ) external nonReentrant {
        require(_amountIn >= minAmount, "OneClick: too small input amount");
        require(
            _poolTokens.length <= 4 && _poolTokens.length >= 2,
            "OneClick: pool size range is: min 2, max 4"
        );

        require(
            IERC20(_route[0][0]).allowance(msg.sender, address(this)) >=
                _amountIn,
            "OneClick: Input token is not approved"
        );

        IERC20(_route[0][0]).safeTransferFrom(
            msg.sender,
            address(this),
            _amountIn
        );

        uint256 lpAmount = _OneClickIn(
            _route,
            _poolAddress,
            _tokenAddress,
            _poolTokens,
            _vault,
            _amountIn,
            _oneToken,
            _indexIn,
            _slippage
        );

        emit NewOneClickIn(
            _route[0][0],
            _poolAddress,
            _amountIn,
            lpAmount,
            msg.sender
        );
    }

    /*
     * @notice OneClick a token out
     * @param _route: The token out and routing for swap
     * @param _poolAddress: Curve pool address
     * @param _tokenAddress: Curve token address
     * @param _poolTokens: Curve tokens in the pool
     * @param _vault: StablecompVault address
     * @param _amountOut: amount of token to remove
     */
    function OneClickOutETH(
        address[][] memory _route,
        address _poolAddress,
        address _tokenAddress,
        address[] memory _poolTokens,
        address _vault,
        uint256 _amountOut
    ) external nonReentrant {
        require(_amountOut >= minAmount, "OneClick: too small input amount");
        require(
            _poolTokens.length <= 4 && _poolTokens.length >= 2,
            "OneClick: pool size range is: min 2, max 4"
        );

        require(
            IERC20(_vault).allowance(msg.sender, address(this)) >= _amountOut,
            "OneClick: Input token is not approved"
        );

        IERC20(_vault).safeTransferFrom(msg.sender, address(this), _amountOut);

        uint256 tokenOutAmount = _OneClickOut(
            _route,
            _poolAddress,
            _tokenAddress,
            _poolTokens,
            _vault,
            wToken,
            _amountOut
        );

        wTokenInterface.withdraw(tokenOutAmount);
        payable(msg.sender).transfer(tokenOutAmount);

        uint256[] memory tokensOutAmount = new uint256[](1);
        tokensOutAmount[0] = tokenOutAmount;

        emit NewOneClickOut(
            address(0x0000000000000000000000000000000000000000),
            _poolAddress,
            _amountOut,
            tokensOutAmount,
            msg.sender
        );
    }

    /*
     * @notice OneClick a token out
     * @param _route: The token out and routing for swap
     * @param _poolAddress: Curve pool address
     * @param _tokenAddress: Curve token address
     * @param _poolTokens: Curve tokens in the pool
     * @param _vault: StablecompVault address
     * @param _tokenOut: token we want to get out
     * @param _amountOut: amount of token to remove
     */
    function OneClickOut(
        address[][] memory _route,
        address _poolAddress,
        address _tokenAddress,
        address[] memory _poolTokens,
        address _vault,
        address _tokenOut,
        uint256 _amountOut
    ) external nonReentrant {
        require(_amountOut >= minAmount, "OneClick: too small input amount");
        require(
            _poolTokens.length <= 4 && _poolTokens.length >= 2,
            "OneClick: pool size range is: min 2, max 4"
        );

        require(
            IERC20(_vault).allowance(msg.sender, address(this)) >= _amountOut,
            "OneClick: Input token is not approved"
        );

        IERC20(_vault).safeTransferFrom(msg.sender, address(this), _amountOut);

        uint256 tokenOutAmount = _OneClickOut(
            _route,
            _poolAddress,
            _tokenAddress,
            _poolTokens,
            _vault,
            _tokenOut,
            _amountOut
        );

        if (_tokenOut == _tokenAddress) {
            uint256[] memory tokensOutAmount = new uint256[](
                _poolTokens.length
            );
            for (uint256 i = 0; i < _poolTokens.length; i++) {
                _approveToken(
                    _poolTokens[i],
                    address(this),
                    IERC20(_poolTokens[i]).balanceOf(address(this))
                );
                IERC20(_poolTokens[i]).safeTransfer(
                    msg.sender,
                    IERC20(_poolTokens[i]).balanceOf(address(this))
                );

                tokensOutAmount[i] = IERC20(_poolTokens[i]).balanceOf(
                    address(this)
                );
            }

            emit NewOneClickOut(
                _tokenOut,
                _poolAddress,
                _amountOut,
                tokensOutAmount,
                msg.sender
            );
        } else {
            uint256[] memory tokensOutAmount = new uint256[](1);
            tokensOutAmount[0] = tokenOutAmount;

            _approveToken(_tokenOut, address(this), tokenOutAmount);
            IERC20(_tokenOut).safeTransferFrom(
                address(this),
                msg.sender,
                tokenOutAmount
            );

            emit NewOneClickOut(
                _tokenOut,
                _poolAddress,
                _amountOut,
                tokensOutAmount,
                msg.sender
            );
        }
    }

    /*
     * @notice estimateOneClickIn a token in (e.g. token/other token)
     * @param _route: The token in and routing for swap (if needed)
     * @param _poolAddress: Curve pool address
     * @param _poolTokens: Curve tokens in the pool
     * @param _oneToken: invest in all tokens or in a one of specified index
     * @param _indexIn: index of the specified to invest
     * @param _slippageUni: slippage for the swap
     * @param _slippageCurve: slippage for the deposit
     */
    function estimateOneClickIn(
        address[][] memory _route,
        address _poolAddress,
        address[] memory _poolTokens,
        address _vault,
        uint256 _amountIn,
        bool _oneToken,
        uint256 _indexIn,
        uint256 _slippageUni,
        uint256 _slippageCurve
    ) external view returns (uint256 amountTokenOut) {
        require(_amountIn >= minAmount, "OneClick: too small input amount");
        require(
            _poolTokens.length <= 4 && _poolTokens.length >= 2,
            "OneClick: pool size range is: min 2, max 4"
        );

        ICurvePool pool = ICurvePool(_poolAddress);

        // If you intend to deposit only one token
        if (_oneToken) {
            require(
                _indexIn <= _poolTokens.length,
                "OneClick: index out of range"
            );

            // If the input token is directly the one to be deposited --> deposit
            if (_route[0][0] == _poolTokens[_indexIn]) {
                if (_poolTokens.length == 2) {
                    uint256[2] memory amounts;
                    amounts[_indexIn] = _amountIn;

                    uint256 slippage = (pool.calc_token_amount(amounts, true) *
                        _slippageCurve) / oneClickMax;

                    uint256 amountCurveOut = pool.calc_token_amount(
                        amounts,
                        true
                    ) - slippage;
                    amountTokenOut =
                        (amountCurveOut * ISCompVault(_vault).totalSupply()) /
                        ISCompVault(_vault).balance();
                } else if (_poolTokens.length == 3) {
                    uint256[3] memory amounts;
                    amounts[_indexIn] = _amountIn;

                    uint256 slippage = (pool.calc_token_amount(amounts, true) *
                        _slippageCurve) / oneClickMax;

                    uint256 amountCurveOut = pool.calc_token_amount(
                        amounts,
                        true
                    ) - slippage;
                    amountTokenOut =
                        (amountCurveOut * ISCompVault(_vault).totalSupply()) /
                        ISCompVault(_vault).balance();
                } else if (_poolTokens.length == 4) {
                    uint256[4] memory amounts;
                    amounts[_indexIn] = _amountIn;

                    uint256 slippage = (pool.calc_token_amount(amounts, true) *
                        _slippageCurve) / oneClickMax;

                    uint256 amountCurveOut = pool.calc_token_amount(
                        amounts,
                        true
                    ) - slippage;
                    amountTokenOut =
                        (amountCurveOut * ISCompVault(_vault).totalSupply()) /
                        ISCompVault(_vault).balance();
                }
            }
            // If the input token does not match the one you want to deposit --> Swap --> Deposit
            else {
                if (_poolTokens.length == 2) {
                    uint256[2] memory amounts;
                    amounts[_indexIn] = estimatePrice(
                        _route[0],
                        _amountIn,
                        _slippageUni
                    );

                    uint256 slippage = (pool.calc_token_amount(amounts, true) *
                        _slippageCurve) / oneClickMax;

                    uint256 amountCurveOut = pool.calc_token_amount(
                        amounts,
                        true
                    ) - slippage;
                    amountTokenOut =
                        (amountCurveOut * ISCompVault(_vault).totalSupply()) /
                        ISCompVault(_vault).balance();
                } else if (_poolTokens.length == 3) {
                    uint256[3] memory amounts;
                    amounts[_indexIn] = estimatePrice(
                        _route[0],
                        _amountIn,
                        _slippageUni
                    );

                    uint256 slippage = (pool.calc_token_amount(amounts, true) *
                        _slippageCurve) / oneClickMax;

                    uint256 amountCurveOut = pool.calc_token_amount(
                        amounts,
                        true
                    ) - slippage;
                    amountTokenOut =
                        (amountCurveOut * ISCompVault(_vault).totalSupply()) /
                        ISCompVault(_vault).balance();
                } else if (_poolTokens.length == 4) {
                    uint256[4] memory amounts;
                    amounts[_indexIn] = estimatePrice(
                        _route[0],
                        _amountIn,
                        _slippageUni
                    );

                    uint256 slippage = (pool.calc_token_amount(amounts, true) *
                        _slippageCurve) / oneClickMax;

                    uint256 amountCurveOut = pool.calc_token_amount(
                        amounts,
                        true
                    ) - slippage;
                    amountTokenOut =
                        (amountCurveOut * ISCompVault(_vault).totalSupply()) /
                        ISCompVault(_vault).balance();
                }
            }
        }
        // If the input token deposit in equal parts to the pool
        else {
            uint256 swapAmount = _amountIn / _poolTokens.length;

            if (_poolTokens.length == 2) {
                uint256[2] memory amounts;
                amounts = _getEstimate(
                    _route,
                    _poolTokens,
                    swapAmount,
                    amounts,
                    _slippageUni
                );

                uint256 slippage = (pool.calc_token_amount(amounts, true) *
                    _slippageCurve) / oneClickMax;

                uint256 amountCurveOut = pool.calc_token_amount(amounts, true) -
                    slippage;
                amountTokenOut =
                    (amountCurveOut * ISCompVault(_vault).totalSupply()) /
                    ISCompVault(_vault).balance();
            } else if (_poolTokens.length == 3) {
                uint256[3] memory amounts;
                amounts = _getEstimate(
                    _route,
                    _poolTokens,
                    swapAmount,
                    amounts,
                    _slippageUni
                );

                uint256 slippage = (pool.calc_token_amount(amounts, true) *
                    _slippageCurve) / oneClickMax;

                uint256 amountCurveOut = pool.calc_token_amount(amounts, true) -
                    slippage;
                amountTokenOut =
                    (amountCurveOut * ISCompVault(_vault).totalSupply()) /
                    ISCompVault(_vault).balance();
            } else if (_poolTokens.length == 4) {
                uint256[4] memory amounts;
                amounts = _getEstimate(
                    _route,
                    _poolTokens,
                    swapAmount,
                    amounts,
                    _slippageUni
                );

                uint256 slippage = (pool.calc_token_amount(amounts, true) *
                    _slippageCurve) / oneClickMax;

                uint256 amountCurveOut = pool.calc_token_amount(amounts, true) -
                    slippage;
                amountTokenOut =
                    (amountCurveOut * ISCompVault(_vault).totalSupply()) /
                    ISCompVault(_vault).balance();
            }
        }
    }

    function estimateOneClickOut()
        external
        view
        returns (uint256 amountTokenOut)
    {}

    function estimatePrice(
        address[] memory _path,
        uint256 _swapAmount,
        uint256 _slippage
    ) public view returns (uint256 amountOut) {
        require(_path.length >= 2, "Estimate Price: path size is: min 2");

        uint256[] memory amountsOut = router.getAmountsOut(_swapAmount, _path);
        uint256 slippage = (amountsOut[amountsOut.length - 1] * _slippage) /
            oneClickMax;
        amountOut = amountsOut[amountsOut.length - 1] - slippage;
    }

    /**
     * @notice Set the new address and the new % for the zapper fees
     * @param _newAddressFee: the address where to send the zapper fees
     * @param _newVauleFee: the fee percentage for each transaction
     * @dev This function is only callable by owner.
     */
    function setOneclickFee(
        address _newAddressFee,
        uint256 _newVauleFee
    ) external {
        _onlyTimeLockController();

        require(
            _newAddressFee != address(0),
            "OneClick: Fee Address not allowed"
        );
        require(
            _newVauleFee >= 0 && _newVauleFee <= oneClickMax,
            "OneClick: Fee Value not allowed"
        );
        oneClickFeeAddress = _newAddressFee;
        oneClickFee = _newVauleFee;
    }

    /**
     * @notice Change TimeLockController address
     * @notice Can only be changed by owner itself
     * @param _timeLockController: the new address of the TimeLockController
     * @dev This function is only callable by owner.
     */
    function setTimeLockController(
        address _timeLockController
    ) public onlyOwner {
        timeLockController = _timeLockController;
    }

    /**
     * @notice It allows the owner to recover wrong tokens sent to the contract
     * @param _token: the address of the token to withdraw (18 decimals)
     * @param _amount: the number of token amount to withdraw
     * @dev This function is only callable by owner.
     */
    function recoverTokens(address _token, uint256 _amount) external onlyOwner {
        IERC20(_token).safeTransfer(msg.sender, _amount);
        emit TokenRecovery(_token, _amount);
    }

    // Internal functions

    function _OneClickIn(
        address[][] memory _route,
        address _poolAddress,
        address _tokenAddress,
        address[] memory _poolTokens,
        address _vault,
        uint256 _amountIn,
        bool _oneToken,
        uint256 _indexIn,
        uint256 _slippage
    ) internal returns (uint256) {
        uint256 amountIn = _fee(_route[0][0], _amountIn);

        uint256 lpAmount;

        // If you intend to deposit only one token
        if (_oneToken) {
            require(
                _indexIn <= _poolTokens.length,
                "OneClick: index out of range"
            );

            // If the input token is directly the one to be deposited --> deposit
            if (_route[0][0] == _poolTokens[_indexIn]) {
                if (_poolTokens.length == 2) {
                    uint256[2] memory amounts;
                    amounts[_indexIn] = amountIn;

                    lpAmount = _add_liquidity(
                        _poolAddress,
                        _tokenAddress,
                        _poolTokens,
                        _vault,
                        amounts,
                        _slippage
                    );
                } else if (_poolTokens.length == 3) {
                    uint256[3] memory amounts;
                    amounts[_indexIn] = amountIn;

                    lpAmount = _add_liquidity(
                        _poolAddress,
                        _tokenAddress,
                        _poolTokens,
                        _vault,
                        amounts,
                        _slippage
                    );
                } else if (_poolTokens.length == 4) {
                    uint256[4] memory amounts;
                    amounts[_indexIn] = amountIn;

                    lpAmount = _add_liquidity(
                        _poolAddress,
                        _tokenAddress,
                        _poolTokens,
                        _vault,
                        amounts,
                        _slippage
                    );
                }
            } else {
                // If the input token does not match the one you want to deposit --> Swap --> Deposit
                address[] memory path = _route[0];
                uint256[] memory swapedAmounts;

                _approveToken(path[0], routerAddress, amountIn);

                swapedAmounts = router.swapExactTokensForTokens(
                    amountIn,
                    1,
                    path,
                    address(this),
                    block.timestamp
                );

                if (_poolTokens.length == 2) {
                    uint256[2] memory amounts;
                    amounts[_indexIn] = swapedAmounts[swapedAmounts.length - 1];

                    lpAmount = _add_liquidity(
                        _poolAddress,
                        _tokenAddress,
                        _poolTokens,
                        _vault,
                        amounts,
                        _slippage
                    );
                } else if (_poolTokens.length == 3) {
                    uint256[3] memory amounts;
                    amounts[_indexIn] = swapedAmounts[swapedAmounts.length - 1];

                    lpAmount = _add_liquidity(
                        _poolAddress,
                        _tokenAddress,
                        _poolTokens,
                        _vault,
                        amounts,
                        _slippage
                    );
                } else if (_poolTokens.length == 4) {
                    uint256[4] memory amounts;
                    amounts[_indexIn] = swapedAmounts[swapedAmounts.length - 1];

                    lpAmount = _add_liquidity(
                        _poolAddress,
                        _tokenAddress,
                        _poolTokens,
                        _vault,
                        amounts,
                        _slippage
                    );
                }
            }
        }
        // If the input token deposit in equal parts to the pool
        else {
            require(
                _route.length == _poolTokens.length,
                "OneClick: route path not match"
            );
            uint256 swapAmount = amountIn / _poolTokens.length;
            address[][] memory ruote = _route;
            address poolAddress = _poolAddress;
            address[] memory poolToken = _poolTokens;
            address tokenAddress = _tokenAddress;
            address vault = _vault;
            uint256 slippage = _slippage;

            if (_poolTokens.length == 2) {
                uint256[2] memory amounts;
                lpAmount = _swapAndDeposit(
                    poolAddress,
                    tokenAddress,
                    ruote,
                    poolToken,
                    vault,
                    swapAmount,
                    amounts,
                    slippage
                );
            } else if (_poolTokens.length == 3) {
                uint256[3] memory amounts;
                lpAmount = _swapAndDeposit(
                    poolAddress,
                    tokenAddress,
                    ruote,
                    poolToken,
                    vault,
                    swapAmount,
                    amounts,
                    slippage
                );
            } else if (_poolTokens.length == 4) {
                uint256[4] memory amounts;
                lpAmount = _swapAndDeposit(
                    poolAddress,
                    tokenAddress,
                    ruote,
                    poolToken,
                    vault,
                    swapAmount,
                    amounts,
                    slippage
                );
            }
        }
        return lpAmount;
    }

    function _OneClickOut(
        address[][] memory _route,
        address _poolAddress,
        address _tokenAddress,
        address[] memory _poolTokens,
        address _vault,
        address _tokenOut,
        uint256 _amountOut
    ) internal returns (uint256 tokeOutAmount) {
        uint256 lpAmount = ISCompVault(_vault).withdrawOneClick(_amountOut, address(this));

        if (_tokenOut == _tokenAddress) {
            if (_poolTokens.length == 2) {
                uint256[2] memory amountOutMin;
                ICurvePool(_poolAddress).remove_liquidity(
                    _amountOut,
                    amountOutMin
                );
            } else if (_poolTokens.length == 3) {
                uint256[3] memory amountOutMin;
                ICurvePool(_poolAddress).remove_liquidity(
                    _amountOut,
                    amountOutMin
                );
            } else if (_poolTokens.length == 4) {
                uint256[4] memory amountOutMin;
                ICurvePool(_poolAddress).remove_liquidity(
                    _amountOut,
                    amountOutMin
                );
            }
        } else {
            if (_poolTokens.length == 2) {
                uint256[2] memory amountOutMin;
                tokeOutAmount = _removeAndSwap(
                    _route,
                    _poolAddress,
                    _poolTokens,
                    _tokenOut,
                    lpAmount,
                    amountOutMin
                );
            } else if (_poolTokens.length == 3) {
                uint256[3] memory amountOutMin;
                tokeOutAmount = _removeAndSwap(
                    _route,
                    _poolAddress,
                    _poolTokens,
                    _tokenOut,
                    lpAmount,
                    amountOutMin
                );
            } else if (_poolTokens.length == 4) {
                uint256[4] memory amountOutMin;
                tokeOutAmount = _removeAndSwap(
                    _route,
                    _poolAddress,
                    _poolTokens,
                    _tokenOut,
                    lpAmount,
                    amountOutMin
                );
            }
        }
        return tokeOutAmount;
    }

    function _swapAndDeposit(
        address _poolAddress,
        address _tokenAddress,
        address[][] memory _route,
        address[] memory _poolTokens,
        address _vault,
        uint256 _swapAmount,
        uint256[2] memory _amounts,
        uint256 _slippage
    ) internal returns (uint256) {
        for (uint256 i = 0; i < _route.length; i++) {
            // If token in does not match token[i] of pool
            if (_route[0][0] != _poolTokens[i]) {
                uint256[] memory swapedAmounts;

                address[] memory path = _route[i];

                _approveToken(path[0], routerAddress, _swapAmount);

                swapedAmounts = router.swapExactTokensForTokens(
                    _swapAmount,
                    1,
                    path,
                    address(this),
                    block.timestamp
                );

                _amounts[i] = swapedAmounts[swapedAmounts.length - 1];
            }
            // If the token in matches the token[i] of the pool
            else {
                _amounts[i] = _swapAmount;
            }
        }
        return
            _add_liquidity(
                _poolAddress,
                _tokenAddress,
                _poolTokens,
                _vault,
                _amounts,
                _slippage
            );
    }

    function _swapAndDeposit(
        address _poolAddress,
        address _tokenAddress,
        address[][] memory _route,
        address[] memory _poolTokens,
        address _vault,
        uint256 _swapAmount,
        uint256[3] memory _amounts,
        uint256 _slippage
    ) internal returns (uint256) {
        for (uint256 i = 0; i < _route.length; i++) {
            // If token in does not match token[i] of pool
            if (_route[0][0] != _poolTokens[i]) {
                uint256[] memory swapedAmounts = new uint256[](2);

                address[] memory path = _route[i];

                _approveToken(path[0], routerAddress, _swapAmount);

                swapedAmounts = router.swapExactTokensForTokens(
                    _swapAmount,
                    1,
                    path,
                    address(this),
                    block.timestamp
                );

                _amounts[i] = swapedAmounts[swapedAmounts.length - 1];
            }
            // If the token in matches the token[i] of the pool
            else {
                _amounts[i] = _swapAmount;
            }
        }
        return
            _add_liquidity(
                _poolAddress,
                _tokenAddress,
                _poolTokens,
                _vault,
                _amounts,
                _slippage
            );
    }

    function _swapAndDeposit(
        address _poolAddress,
        address _tokenAddress,
        address[][] memory _route,
        address[] memory _poolTokens,
        address _vault,
        uint256 _swapAmount,
        uint256[4] memory _amounts,
        uint256 _slippage
    ) internal returns (uint256) {
        for (uint256 i = 0; i < _route.length; i++) {
            // If token in does not match token[i] of pool
            if (_route[0][0] != _poolTokens[i]) {
                uint256[] memory swapedAmounts;

                address[] memory path = _route[i];

                _approveToken(path[0], routerAddress, _swapAmount);

                swapedAmounts = router.swapExactTokensForTokens(
                    _swapAmount,
                    1,
                    path,
                    address(this),
                    block.timestamp
                );

                _amounts[i] = swapedAmounts[swapedAmounts.length - 1];
            }
            // If the token in matches the token[i] of the pool
            else {
                _amounts[i] = _swapAmount;
            }
        }
        return
            _add_liquidity(
                _poolAddress,
                _tokenAddress,
                _poolTokens,
                _vault,
                _amounts,
                _slippage
            );
    }

    function _add_liquidity(
        address _poolAddress,
        address _tokenAddress,
        address[] memory _poolTokens,
        address _vault,
        uint256[2] memory _amounts,
        uint256 _slippage
    ) internal returns (uint256) {
        _approveToken(_poolTokens[0], _poolAddress, _amounts[0]);
        _approveToken(_poolTokens[1], _poolAddress, _amounts[1]);

        uint256 slippage = (ICurvePool(_poolAddress).calc_token_amount(
            _amounts,
            true
        ) * _slippage) / oneClickMax;
        uint256 amountOutMin = ICurvePool(_poolAddress).calc_token_amount(
            _amounts,
            true
        ) - slippage;

        ICurvePool(_poolAddress).add_liquidity(_amounts, amountOutMin);

        _approveToken(
            _tokenAddress,
            _vault,
            IERC20(_tokenAddress).balanceOf(address(this))
        );

        return ISCompVault(_vault).depositAllFor(msg.sender);
    }

    function _add_liquidity(
        address _poolAddress,
        address _tokenAddress,
        address[] memory _poolTokens,
        address _vault,
        uint256[3] memory _amounts,
        uint256 _slippage
    ) internal returns (uint256) {
        _approveToken(_poolTokens[0], _poolAddress, _amounts[0]);
        _approveToken(_poolTokens[1], _poolAddress, _amounts[1]);
        _approveToken(_poolTokens[2], _poolAddress, _amounts[2]);

        uint256 slippage = (ICurvePool(_poolAddress).calc_token_amount(
            _amounts,
            true
        ) * _slippage) / oneClickMax;
        uint256 amountOutMin = ICurvePool(_poolAddress).calc_token_amount(
            _amounts,
            true
        ) - slippage;
        ICurvePool(_poolAddress).add_liquidity(_amounts, amountOutMin);

        _approveToken(
            _tokenAddress,
            _vault,
            IERC20(_tokenAddress).balanceOf(address(this))
        );

        return ISCompVault(_vault).depositAllFor(msg.sender);
    }

    function _add_liquidity(
        address _poolAddress,
        address _tokenAddress,
        address[] memory _poolTokens,
        address _vault,
        uint256[4] memory _amounts,
        uint256 _slippage
    ) internal returns (uint256) {
        _approveToken(_poolTokens[0], _poolAddress, _amounts[0]);
        _approveToken(_poolTokens[1], _poolAddress, _amounts[1]);
        _approveToken(_poolTokens[2], _poolAddress, _amounts[2]);
        _approveToken(_poolTokens[3], _poolAddress, _amounts[3]);

        uint256 slippage = (ICurvePool(_poolAddress).calc_token_amount(
            _amounts,
            true
        ) * _slippage) / oneClickMax;
        uint256 amountOutMin = ICurvePool(_poolAddress).calc_token_amount(
            _amounts,
            true
        ) - slippage;
        ICurvePool(_poolAddress).add_liquidity(_amounts, amountOutMin);

        _approveToken(
            _tokenAddress,
            _vault,
            IERC20(_tokenAddress).balanceOf(address(this))
        );

        return ISCompVault(_vault).depositAllFor(msg.sender);
    }

    function _removeAndSwap(
        address[][] memory _route,
        address _poolAddress,
        address[] memory _poolTokens,
        address _tokenOut,
        uint256 _amountOut,
        uint256[2] memory _amountOutMin
    ) internal returns (uint256) {
        ICurvePool(_poolAddress).remove_liquidity(_amountOut, _amountOutMin);

        for (uint256 i = 0; i < _poolTokens.length; i++) {
            if (_tokenOut != _poolTokens[i]) {
                _approveToken(
                    _route[i][0],
                    routerAddress,
                    IERC20(_poolTokens[i]).balanceOf(address(this))
                );
                router.swapExactTokensForTokens(
                    IERC20(_poolTokens[i]).balanceOf(address(this)),
                    1,
                    _route[i],
                    address(this),
                    block.timestamp
                );
            }
        }
        return IERC20(_tokenOut).balanceOf(address(this));
    }

    function _removeAndSwap(
        address[][] memory _route,
        address _poolAddress,
        address[] memory _poolTokens,
        address _tokenOut,
        uint256 _amountOut,
        uint256[3] memory _amountOutMin
    ) internal returns (uint256) {
        ICurvePool(_poolAddress).remove_liquidity(_amountOut, _amountOutMin);

        for (uint256 i = 0; i < _poolTokens.length; i++) {
            if (_tokenOut != _poolTokens[i]) {
                _approveToken(
                    _route[i][0],
                    routerAddress,
                    IERC20(_poolTokens[i]).balanceOf(address(this))
                );
                router.swapExactTokensForTokens(
                    IERC20(_poolTokens[i]).balanceOf(address(this)),
                    1,
                    _route[i],
                    address(this),
                    block.timestamp
                );
            }
        }
        return IERC20(_tokenOut).balanceOf(address(this));
    }

    function _removeAndSwap(
        address[][] memory _route,
        address _poolAddress,
        address[] memory _poolTokens,
        address _tokenOut,
        uint256 _amountOut,
        uint256[4] memory _amountOutMin
    ) internal returns (uint256) {
        ICurvePool(_poolAddress).remove_liquidity(_amountOut, _amountOutMin);

        for (uint256 i = 0; i < _poolTokens.length; i++) {
            if (_tokenOut != _poolTokens[i]) {
                _approveToken(
                    _route[i][0],
                    routerAddress,
                    IERC20(_poolTokens[i]).balanceOf(address(this))
                );
                router.swapExactTokensForTokens(
                    IERC20(_poolTokens[i]).balanceOf(address(this)),
                    1,
                    _route[i],
                    address(this),
                    block.timestamp
                );
            }
        }
        return IERC20(_tokenOut).balanceOf(address(this));
    }

    function _getEstimate(
        address[][] memory _route,
        address[] memory _poolTokens,
        uint256 _swapAmount,
        uint256[2] memory _amounts,
        uint256 _slippage
    ) internal view returns (uint256[2] memory) {
        for (uint256 i = 0; i < _route.length; i++) {
            // If token in does not match token[i] of pool
            if (_route[0][0] != _poolTokens[i]) {
                address[] memory path = _route[i];

                _amounts[i] = estimatePrice(path, _swapAmount, _slippage);
            }
            // If the token in matches the token[i] of the pool
            else {
                _amounts[i] = _swapAmount;
            }
        }
        return _amounts;
    }

    function _getEstimate(
        address[][] memory _route,
        address[] memory _poolTokens,
        uint256 _swapAmount,
        uint256[3] memory _amounts,
        uint256 _slippage
    ) internal view returns (uint256[3] memory) {
        for (uint256 i = 0; i < _route.length; i++) {
            // If token in does not match token[i] of pool
            if (_route[0][0] != _poolTokens[i]) {
                address[] memory path = _route[i];

                _amounts[i] = estimatePrice(path, _swapAmount, _slippage);
            }
            // If the token in matches the token[i] of the pool
            else {
                _amounts[i] = _swapAmount;
            }
        }
        return _amounts;
    }

    function _getEstimate(
        address[][] memory _route,
        address[] memory _poolTokens,
        uint256 _swapAmount,
        uint256[4] memory _amounts,
        uint256 _slippage
    ) internal view returns (uint256[4] memory) {
        for (uint256 i = 0; i < _route.length; i++) {
            // If token in does not match token[i] of pool
            if (_route[0][0] != _poolTokens[i]) {
                address[] memory path = _route[i];

                _amounts[i] = estimatePrice(path, _swapAmount, _slippage);
            }
            // If the token in matches the token[i] of the pool
            else {
                _amounts[i] = _swapAmount;
            }
        }
        return _amounts;
    }

    function _fee(
        address _tokenAddress,
        uint256 _amountIn
    ) internal returns (uint256) {
        uint256 fee = (_amountIn * oneClickFee) / oneClickMax;
        IERC20(_tokenAddress).safeTransfer(oneClickFeeAddress, fee);
        return _amountIn - fee;
    }

    function _onlyTimeLockController() internal view {
        require(
            msg.sender == timeLockController,
            "Time Lock Controller: Only Time Lock Controller"
        );
    }

    function _approveToken(
        address _token,
        address _spender,
        uint256 _amountIn
    ) internal {
        IERC20 token = IERC20(_token);
        if (token.allowance(address(this), _spender) < _amountIn) {
            IERC20(_token).safeApprove(_spender, 0);
            IERC20(_token).safeApprove(_spender, maxInt);
        }
    }
}
