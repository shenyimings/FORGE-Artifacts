// SPDX-License-Identifier: MIT
pragma solidity =0.8.11;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "./interfaces/IERC20MintBurn.sol";
import "./interfaces/IJamonSharePresale.sol";
import "./interfaces/IConversor.sol";
import "./interfaces/IJamonRouter.sol";
import "./interfaces/IJamonPair.sol";

/**
 * @title Conversor
 * @notice It allows the conversion of the Jamon token for the new JamonV2 in addition to converting its liquidity with the old token for the liquidity with the new token.
 * liquidity will be the first allowed to convert and once the pre-sale phases of the JamonShare token are finished, it will allow the token to be converted.
 */
contract Conversor is IConversor, Ownable, ReentrancyGuard, Pausable {
    //---------- Libraries ----------//
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    using SafeERC20 for IJamonPair;

    //---------- Contracts ----------//
    IJamonRouter internal Router; // DEX Router contract
    IJamonSharePresale internal Presale; // JamonShare presale contract

    //---------- Variables ----------//
    uint256 private immutable _endTime; // Value in timestamp of the liquidity conversion end date
    bool public Completed_LP; // If the liquidity is completed
    bool public Canceled; // If the conversion
    uint256 public startAt;

    //---------- Storage -----------//
    struct TokensContracts {
        // USDC Contract
        IERC20 USDC;
        // Old Jamon contract
        IERC20 JAMON_V1;
        // New JamonV2 Contract
        IERC20MintBurn JAMON_V2;
        // Old pair MATIC/JAMON contract
        IJamonPair MATIC_LP_V1;
        // Old pair USDC/JAMON contract
        IJamonPair USDC_LP_V1;
        // New pair MATIC/JAMONV2 contract
        IJamonPair MATIC_LP_V2;
        // New pair USDC/JAMONV2 contract
        IJamonPair USDC_LP_V2;
    }

    struct Tokens {
        // Total LP MATIC/JAMON aported
        uint256 TotalOldMaticLP;
        // Total LP MATIC/JAMONV2 created
        uint256 TotalNewMaticLP;
        // Total LP USDC/JAMON aported
        uint256 TotalOldUsdcLP;
        // Total LP USDC/JAMON created
        uint256 TotalNewUsdcLP;
    }

    struct Wallet {
        // Amount of LP MATIC/JAMON aported by wallet
        uint256 MaticLpBalance;
        // Amount of LP USDC/JAMON aported by wallet
        uint256 USDCLpBalance;
    }

    mapping(address => Wallet) public Wallets; // Map of wallets that have provided liquidity
    TokensContracts internal Contracts; // Struct of the contracts necessary for the operation
    Tokens public Balances; // Struct of the old and new balances

    //---------- Events -----------//
    event Deposit(
        address indexed token,
        address indexed wallet,
        uint256 amount
    );
    event Updated(address indexed wallet, uint256 amount);
    event ClaimedLP(address indexed wallet, uint256[2] amounts);

    //---------- Constructor ----------//
    constructor(
        address oldToken_,
        address newToken_,
        address usdc_
    ) {
        Router = IJamonRouter(0xdBe30E8742fBc44499EB31A19814429CECeFFaA0);
        startAt = 1643911200; // Thu Feb 03 2022 18:00:00 GMT+0000
        _endTime = startAt.add(3 days); // 3 days update lps period
        Contracts.JAMON_V1 = IERC20(oldToken_);
        Contracts.JAMON_V2 = IERC20MintBurn(newToken_);
        Contracts.USDC = IERC20(usdc_);
    }

    function initialize(
        address maticlpV1,
        address usdclpV1,
        address maticlpV2,
        address usdclpV2,
        address presale
    ) external onlyOwner {
        require(
            address(Contracts.MATIC_LP_V1) == address(0x0),
            "Already initialized"
        );
        Contracts.MATIC_LP_V1 = IJamonPair(maticlpV1);
        Contracts.USDC_LP_V1 = IJamonPair(usdclpV1);
        Contracts.MATIC_LP_V2 = IJamonPair(maticlpV2);
        Contracts.USDC_LP_V2 = IJamonPair(usdclpV2);
        Presale = IJamonSharePresale(presale);
    }

    //---------- Modifiers ----------//
    /**
     * @dev Reverts if the LP token is not supported.
     */
    modifier onlyTokens(address token_) {
        require(
            token_ == address(Contracts.MATIC_LP_V1) ||
                token_ == address(Contracts.USDC_LP_V1),
            "Invalid token"
        );
        _;
    }

    //----------- Internal Functions -----------//
    /**
     * @dev Calculates the amount of new liquidity to receive with respect to the contribution of old liquidity.
     * @param balance_ Amount of old liquidity contributed.
     * @param oldTotal_ Total amount of old liquidity contributed.
     * @param newTotal_ Total amount of new liquidity created.
     * @return uint256 amount of new liquidity corresponding to the amount of old liquidity contributed.
     */
    function _getTokensAmount(
        uint256 balance_,
        uint256 oldTotal_,
        uint256 newTotal_
    ) internal pure returns (uint256) {
        uint256 oldPercent = balance_.mul(10e18).div(oldTotal_);
        uint256 newBalance = oldPercent.mul(newTotal_).div(10e18);
        return newBalance;
    }

    //----------- External Functions -----------//
    /**
     * @notice Show the date in timestamp on which the liquidity conversion ends.
     * @return The timestamp at which it ends.
     */
    function endTime() external view override returns (uint256) {
        return _endTime;
    }

    /**
     * @notice Convert the old liquidity for the new one, the tokens will be retained until the end of the allowed time and they will be distributed once the conversion is completed.
     * @param token_ The address of the lp token to convert.
     * @param amount_ The amount of lp token to convert.
     */
    function updateLP(address token_, uint256 amount_)
        external
        whenNotPaused
        nonReentrant
        onlyTokens(token_)
    {
        require(amount_ > 0, "Invalid amount");
        require(
            block.timestamp < _endTime && block.timestamp > startAt,
            "Out of time"
        );
        IERC20(token_).safeTransferFrom(_msgSender(), address(this), amount_);
        Wallet storage w = Wallets[_msgSender()];
        if (token_ == address(Contracts.MATIC_LP_V1)) {
            w.MaticLpBalance += amount_;
            Balances.TotalOldMaticLP += amount_;
        }
        if (token_ == address(Contracts.USDC_LP_V1)) {
            w.USDCLpBalance += amount_;
            Balances.TotalOldUsdcLP += amount_;
        }
        emit Deposit(token_, _msgSender(), amount_);
    }

    /**
     * @notice Convert the old token Jamon for the new one, the conversion will be allowed once the pre-sale rounds of the JamonShare token end.
     * @param amount_ The amount of old Jamon token to convert.
     */
    function update(uint256 amount_) external whenNotPaused nonReentrant {
        require(amount_ > 0, "Invalid amount");
        (uint256 round, ) = Presale.status();
        require(round == 4 && Completed_LP, "Presale not ended");
        Contracts.JAMON_V1.safeTransferFrom(
            _msgSender(),
            0x000000000000000000000000000000000000dEaD,
            amount_
        );
        Contracts.JAMON_V2.mint(_msgSender(), amount_);
        emit Updated(_msgSender(), amount_);
    }

    /**
     * @notice Allows you to claim the new liquidity provided once the conversion is complete.
     */
    function claimLP() external whenNotPaused nonReentrant {
        require(Completed_LP, "Not completed");
        Wallet storage w = Wallets[_msgSender()];
        require(w.MaticLpBalance > 0 || w.USDCLpBalance > 0, "Zero balance");
        uint256 MaticLpBalance = w.MaticLpBalance;
        uint256 USDCLpBalance = w.USDCLpBalance;
        uint256[2] memory amounts;
        if (MaticLpBalance > 0) {
            w.MaticLpBalance = 0;
            uint256 amountLP = _getTokensAmount(
                MaticLpBalance,
                Balances.TotalOldMaticLP,
                Balances.TotalNewMaticLP
            );
            Contracts.MATIC_LP_V2.transfer(_msgSender(), amountLP);
            amounts[0] = amountLP;
        }
        if (USDCLpBalance > 0) {
            w.USDCLpBalance = 0;
            uint256 amountLP = _getTokensAmount(
                USDCLpBalance,
                Balances.TotalOldUsdcLP,
                Balances.TotalNewUsdcLP
            );
            Contracts.USDC_LP_V2.transfer(_msgSender(), amountLP);
            amounts[1] = amountLP;
        }
        delete Wallets[_msgSender()];
        emit ClaimedLP(_msgSender(), amounts);
    }

    /**
     * @notice Allows you to claim the old liquidity provided if conversion is canceled.
     */
    function safeWithdrawn() external nonReentrant {
        require(!Completed_LP && Canceled, "Not canceled");
        Wallet storage w = Wallets[_msgSender()];
        require(w.MaticLpBalance > 0 || w.USDCLpBalance > 0, "Zero balance");
        uint256 MaticLpBalance = w.MaticLpBalance;
        uint256 USDCLpBalance = w.USDCLpBalance;
        uint256[2] memory amounts;
        if (MaticLpBalance > 0) {
            w.MaticLpBalance = 0;
            Contracts.MATIC_LP_V1.transfer(_msgSender(), MaticLpBalance);
            amounts[0] = MaticLpBalance;
        }
        if (USDCLpBalance > 0) {
            w.USDCLpBalance = 0;
            Contracts.USDC_LP_V1.transfer(_msgSender(), USDCLpBalance);
            amounts[1] = USDCLpBalance;
        }
        delete Wallets[_msgSender()];
        emit ClaimedLP(_msgSender(), amounts);
    }

    /**
     * @notice Complete the liquidity conversion phase, undo the old liquidity to create new liquidity with the obtained tokens.
     */
    function completeLP() external onlyOwner {
        require(
            !Completed_LP && block.timestamp > _endTime && !Canceled,
            "Already completed or cancelled"
        );
        uint256 oldMaticLpBalance = Contracts.MATIC_LP_V1.balanceOf(
            address(this)
        );
        uint256 oldUsdcLpBalance = Contracts.USDC_LP_V1.balanceOf(
            address(this)
        );
        if (oldMaticLpBalance > 0) {
            Contracts.MATIC_LP_V1.approve(address(Router), oldMaticLpBalance);
            (uint256 TokenA, uint256 TokenB) = Router.removeLiquidity(
                address(Router.WETH()),
                address(Contracts.JAMON_V1),
                oldMaticLpBalance,
                1,
                1,
                address(this),
                block.timestamp.add(120)
            );
            require(TokenA > 0 && TokenB > 0, "Matic LP remove zero");
            IERC20(Router.WETH()).approve(address(Router), TokenA);
            Contracts.JAMON_V2.mint(address(this), TokenB);
            Contracts.JAMON_V2.approve(address(Router), TokenB);
            (, , uint256 liquidity) = Router.addLiquidity(
                address(Router.WETH()),
                address(Contracts.JAMON_V2),
                TokenA,
                TokenB,
                1,
                1,
                address(this),
                block.timestamp.add(120)
            );
            require(liquidity > 0, "Matic LP liquidity zero");
            Balances.TotalNewMaticLP = liquidity;
        }
        if (oldUsdcLpBalance > 0) {
            Contracts.USDC_LP_V1.approve(address(Router), oldUsdcLpBalance);
            (uint256 TokenA, uint256 TokenB) = Router.removeLiquidity(
                address(Contracts.USDC),
                address(Contracts.JAMON_V1),
                oldUsdcLpBalance,
                1,
                1,
                address(this),
                block.timestamp.add(120)
            );
            require(TokenA > 0 && TokenB > 0, "USDC LP remove zero");
            Contracts.USDC.approve(address(Router), TokenA);
            Contracts.JAMON_V2.mint(address(this), TokenB);
            Contracts.JAMON_V2.approve(address(Router), TokenB);
            (, , uint256 liquidity) = Router.addLiquidity(
                address(Contracts.USDC),
                address(Contracts.JAMON_V2),
                TokenA,
                TokenB,
                1,
                1,
                address(this),
                block.timestamp.add(120)
            );
            require(liquidity > 0, "USDC LP liquidity zero");
            Balances.TotalNewUsdcLP = liquidity;
        }
        Completed_LP = true;
    }

    /**
     * @notice Allow to cancel de conversion if add liquidity fails.
     */
    function cancelConversion() external onlyOwner {
        require(!Completed_LP, "Conversion completed");
        Canceled = true;
    }

    /**
     * @notice Functions for pause and unpause the contract.
     */
    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }
}
