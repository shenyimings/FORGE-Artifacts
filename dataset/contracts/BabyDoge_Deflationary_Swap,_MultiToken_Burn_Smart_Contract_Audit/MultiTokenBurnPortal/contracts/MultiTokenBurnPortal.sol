// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./interfaces/IBabyDogeRouter.sol";
import "./interfaces/IWETH.sol";
import "./SafeOwnable.sol";

/*
 * @title Allows buying fee on transfer ERC20 tokens with lower fee.
 * Fee discount is determined by amount of tokens were burned by specific user.
 * Leftover income is distributed between adminFeeReceiver and token's feeReceiver
 * Owner sets managers, tokens IN, and admin fee settings (share and admin fee receiver)
 * Manager and owner add/remove active tokens, set discount settings and token fee settings
 */
contract MultiTokenBurnPortal is SafeOwnable, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.AddressSet;

    struct Discount {
        // Discount amount in basis points, where 10_000 is 100% discount, which means purchase without fees
        uint16 discount;
        // Amount of tokens to burn to reach this discount
        uint112 burnAmount;
    }

    struct BurnPortal {
        uint16 baseTax;
        address feeReceiver;
        uint256 totalBought;
        uint256 totalBurned;
        Discount[] discounts;
    }

    IWETH private immutable WETH;
    address private constant DEAD_WALLET = 0x000000000000000000000000000000000000dEaD;
    uint16 public adminFee;
    address public adminFeeReceiver;

    // account => token address => burnedAmount
    mapping(address => mapping(address => uint256)) public burnedAmount;
    mapping(address => BurnPortal) private portals;

    EnumerableSet.AddressSet private managers;          // Set of token managers
    EnumerableSet.AddressSet private approvedRouters;   // Set of V2 routers addresses, approved to be used
    EnumerableSet.AddressSet private approvedTokensIn;  // Set of token addresses, approved to be TokenIn
    EnumerableSet.AddressSet private activeTokens;      // Set of token addresses, approved to be burned and purchased

    event TokenPurchase(
        address indexed token,
        address account,
        uint256 purchasedAmount,
        address tokenIn
    );
    event TokensBurn(address indexed token, address account, uint256 amount);
    // Token In
    event TokenInApproved(address);
    event TokenInRemoved(address);
    // Active tokens
    event TokenAdded(address token, uint16 baseTax, address feeReceiver, Discount[] discounts);
    event TokenRemoved(address token);
    event RouterApproved(address router, bool approved);
    event DiscountsUpdated(address indexed token, Discount[]);
    event BaseTaxUpdated(address indexed token, uint16 newBaseTax);
    event FeeReceiverUpdated(address indexed token, address feeReceiver);

    event NewManager(address);
    event ManagerRemoved(address);
    event AdminFeeSettingsUpdated(uint16 adminFee, address adminFeeReceiver);

    event EmergencyTokensWithdrawal(address token, address account, uint256 amount);
    event EmergencyBnbWithdrawal(address account, uint256 amount);

    error InvalidDiscount(uint256);

    modifier onlyOwnerOrManager() {
        require(msg.sender == owner() || managers.contains(msg.sender), "Not owner/manager");
        _;
    }

    modifier onlyApprovedRouter(address router) {
        require(approvedRouters.contains(router), "Router not approved");
        _;
    }


    /*
     * @param _WETH WETH address
     * @param _adminFee Admin fee in basis points (10000 = 100%). This fee share will be transferred to admin fee receiver
     * @param _adminFeeReceiver Receiver of admin fees
     */
    constructor(
        IWETH _WETH,
        uint16 _adminFee,
        address _adminFeeReceiver
    ){
        WETH = _WETH;

        adminFee = _adminFee;
        adminFeeReceiver = _adminFeeReceiver;
    }


    /*
     * @notice Swaps BNB for Token and sends them to msg.sender
     * @param router Router address, that should be used for the swap
     * @param amountOutMin Minimum amount of tokens to receive
     * @param path Swap path
     * @param deadline Deadline of swap transaction
     * @return amountOut Amount of tokens user has received
     */
    function buyTokensWithBNB(
        address router,
        uint256 amountOutMin,
        address[] calldata path,
        uint256 deadline
    ) external payable onlyApprovedRouter(router) nonReentrant returns(uint256 amountOut){
        require(path[0] == address(WETH) && path.length == 2, "Invalid path");
        require(msg.value > 0, "0 amountIn");

        (uint256 taxAmount, uint256 adminFeeAmount) = _getFees(path[path.length - 1], msg.value);
        if (taxAmount > 0) {
            if (adminFeeAmount > 0) {
                (bool success,) = payable(adminFeeReceiver).call{ value: adminFeeAmount }("");
                require(success, "Couldn't pay admin fee");
            }
            if (taxAmount - adminFeeAmount > 0) {
                (bool success,) = payable(
                    portals[path[path.length - 1]].feeReceiver
                ).call{ value: taxAmount - adminFeeAmount }("");
                require(success, "Couldn't pay fee");
            }
        }
        uint256 amountIn = msg.value - taxAmount;

        WETH.deposit{value : amountIn}();

        amountOut = _buyTokenWithERC20(
            router,
            amountIn,
            amountOutMin,
            path,
            deadline
        );
    }


    /*
     * @notice Swaps ERC20 for token and sends them to msg.sender
     * @param router Router address, that should be used for the swap
     * @param amountIn Amount tokens to spend
     * @param amountOutMin Minimum amount of tokens to receive
     * @param path Swap path
     * @param deadline Deadline of swap transaction
     * @return amountOut Amount of tokens user has received
     */
    function buyTokensWithERC20(
        address router,
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        uint256 deadline
    ) external onlyApprovedRouter(router) nonReentrant returns(uint256 amountOut){
        // allow only WBNB -> Portal Token or Stable -> Portal Token or Stable -> WBNB -> Portal Token swaps
        require(
            (path.length == 2 && (path[0] == address(WETH) || approvedTokensIn.contains(path[0])))
            ||
            (path.length == 3 && path[1] == address(WETH) && approvedTokensIn.contains(path[0])),
            "Forbidden swap path"
        );

        IERC20(path[0]).safeTransferFrom(msg.sender, address(this), amountIn);
        (uint256 taxAmount, uint256 adminFeeAmount) = _getFees(path[path.length - 1], amountIn);
        if (taxAmount > 0) {
            if (adminFeeAmount > 0) {
                IERC20(path[0]).safeTransfer(adminFeeReceiver, adminFeeAmount);
            }
            if (taxAmount - adminFeeAmount > 0) {
                IERC20(path[0]).safeTransfer(
                    portals[path[path.length - 1]].feeReceiver,
                    taxAmount - adminFeeAmount
                );
            }
        }
        uint256 amountInWithTax = amountIn  - taxAmount;

        amountOut = _buyTokenWithERC20(
            router,
            amountInWithTax,
            amountOutMin,
            path,
            deadline
        );
    }


    /*
     * @notice Burns tokens by sending them to dead wallet
     * @param token ERC20 token address to burn
     * @param amount Amount of tokens to burn
     */
    function burnTokens(address token, uint256 amount) external {
        IERC20(token).safeTransferFrom(msg.sender, DEAD_WALLET, amount);
        burnedAmount[msg.sender][token] += amount;
        portals[token].totalBurned += amount;

        emit TokensBurn(token, msg.sender, amount);
    }


    /*
     * @notice Sets manager account
     * @param account Account address
     * @param add true - add manager, false - remove manager
     */
    function setManager(address account, bool add) external onlyOwner {
        if (add) {
            require(managers.add(account), "Already added");
            emit NewManager(account);
        } else {
            require(managers.remove(account), "Not a manager");
            emit ManagerRemoved(account);
        }
    }


    /*
     * @notice Sets admin fee and admin fee receiver
     * @param _adminFee Admin fee in basis points (10000 = 100%). This fee share will be transferred to admin fee receiver
     * @param _adminFeeReceiver Receiver of admin fees
     */
    function setAdminFeeSettings(
        uint16 _adminFee,
        address _adminFeeReceiver
    ) external onlyOwner {
        require(_adminFee <= 10_000, "adminFee > 10000");
        require(_adminFeeReceiver != address(0), "Zero address");
        adminFeeReceiver = _adminFeeReceiver;
        adminFee = _adminFee;

        emit AdminFeeSettingsUpdated(_adminFee, _adminFeeReceiver);
    }


    /*
     * @notice Creates a burn portal for new token
     * @param token ERC20 token address
     * @param baseTax Base tax for the token, in basis points (10000 = 100%)
     * @param feeReceiver Fee receiver address for the token
     * @param discounts Array of Discount structs, containing discount amount and burn amount to receive that discount
     */
    function addToken(
        address token,
        uint16 baseTax,
        address feeReceiver,
        Discount[] calldata discounts
    ) external onlyOwnerOrManager {
        require(activeTokens.add(token), "Already added");
        require(baseTax < 10_000, "baseTax >= 10_000");

        _setDiscounts(token, discounts);
        portals[token].baseTax = baseTax;
        portals[token].feeReceiver = feeReceiver;

        emit TokenAdded(token, baseTax, feeReceiver, discounts);
    }


    /*
     * @notice Removes token from Burn Portal
     * @param token ERC20 token address
     */
    function removeToken(address token) external onlyOwnerOrManager {
        require(activeTokens.remove(token), "Not active token");
        portals[token].feeReceiver = address(0);

        emit TokenRemoved(token);
    }


    /*
     * @notice Sets new base tax for the token
     * @param token ERC20 token address
     * @param baseTax Base tax for the token, in basis points (10000 = 100%)
     */
    function setTokenBaseTax(
        address token,
        uint16 baseTax
    ) external onlyOwnerOrManager {
        require(baseTax < 10_000, "baseTax >= 10_000");
        require(portals[token].baseTax != baseTax, "Already set");
        portals[token].baseTax = baseTax;

        emit BaseTaxUpdated(token, baseTax);
    }


    /*
     * @notice Updates fee receiver address for specific token
     * @param token ERC20 token address
     * @param feeReceiver Fee receiver address for the token
     */
    function setTokenFeeReceiver(
        address token,
        address feeReceiver
    ) external onlyOwnerOrManager {
        require(portals[token].feeReceiver != feeReceiver, "Already set");
        portals[token].feeReceiver = feeReceiver;

        emit FeeReceiverUpdated(token, feeReceiver);
    }


    /*
     * @notice Updates discounts for specific token
     * @param token ERC20 token address
     * @param discounts Array of Discount structs, containing discount amount and burn amount to receive that discount
     */
    function setTokenDiscounts(
        address token,
        Discount[] calldata discounts
    ) external onlyOwnerOrManager {
        _setDiscounts(token, discounts);
    }


    /*
     * @notice Approves token to be swapped to Portal Token
     * @param token ERC20 token address
     */
    function approveTokenIn(address token) external onlyOwner {
        require(!approvedTokensIn.contains(token), "Already approved");
        approvedTokensIn.add(token);

        emit TokenInApproved(token);
    }


    /*
     * @notice Remove token from the list of approved tokens In
     * @param token ERC20 token address
     */
    function removeTokenIn(address token) external onlyOwner {
        require(approvedTokensIn.contains(token), "Not approved");
        approvedTokensIn.remove(token);

        emit TokenInRemoved(token);
    }


    /*
     * @notice Approves Router address
     * @param router Router address
     * @param approve true - approve, false - forbid
     */
    function approveRouter(address router, bool approve) external onlyOwner {
        if (approve) {
            require(approvedRouters.add(router), "Already approved");
        } else {
            require(approvedRouters.remove(router), "Not approved");
        }

        emit RouterApproved(router, approve);
    }


    /*
     * @notice Withdraws stuck ERC20 token.
     * @param token IERC20 token address
     * @param account Address of receiver
     * @param amount Amount of tokens to withdraw
     */
    function emergencyWithdrawERC20(
        IERC20 token,
        address account,
        uint256 amount
    ) external onlyOwner {
        token.safeTransfer(account, amount);

        emit EmergencyTokensWithdrawal(address(token), account, amount);
    }


    /*
     * @notice Withdraws stuck BNB.
     * @param account Address of receiver
     * @param amount Amount of BNB to withdraw
     */
    function emergencyWithdrawBNB(
        address account,
        uint256 amount
    ) external onlyOwner {
        (bool success, ) = account.call{value: amount}("");
        require(success, "Failed to send BNB");

        emit EmergencyBnbWithdrawal(account, amount);
    }


    /*
     * @notice View function go get discounts list for specific token
     * @param token ERC20 token address
     * @return List or discounts
     */
    function getDiscounts(address token) external view returns(Discount[] memory) {
        return portals[token].discounts;
    }


    /*
     * @notice View function go get list or approved tokens
     * @return List or approved tokens
     */
    function getApprovedTokens() external view returns(address[] memory) {
        return approvedTokensIn.values();
    }


    /*
     * @notice View function go get list or approved routers
     * @return List or approved routers
     */
    function getApprovedRouters() external view returns(address[] memory) {
        return approvedRouters.values();
    }


    /*
     * @notice View function go get list or active Portal Tokens
     * @return List or active Portal Tokens
     */
    function getActiveTokens() external view returns(address[] memory) {
        return activeTokens.values();
    }


    /*
     * @notice View function go collect portal info
     * @param token Portal Token address
     * @return baseTax Token tax in basis points (10000 = 100%)
     * @return feeReceiver Fee receiver for this token
     * @return totalBought Amount of tokens, bought through this portal
     * @return totalBurned Amount of tokens, burned with this portal
     * @return discounts List of token discounts
     */
    function getPortalInfo(address token) external view returns(
        uint16 baseTax,
        address feeReceiver,
        uint256 totalBought,
        uint256 totalBurned,
        Discount[] memory discounts
    ) {
        BurnPortal memory portalInfo = portals[token];
        return (
            portalInfo.baseTax,
            portalInfo.feeReceiver,
            portalInfo.totalBought,
            portalInfo.totalBurned,
            portalInfo.discounts
        );
    }


    /*
     * @notice View function to get list or managers
     * @return List or managers
     */
    function getManagers() external view returns(address[] memory) {
        return managers.values();
    }


    /*
     * @notice View function check if address is manager
     * @param account Account address
     * @return Is account a manager?
     */
    function isManager(address account) external view returns(bool) {
        return managers.contains(account);
    }


    /*
     * @notice View function go determine if token is approved to be swapped to Portal Token
     * @param token ERC20 token address
     * @return Is approved to be swapped to Portal Token?
     */
    function isApprovedTokenIn(address token) external view returns(bool) {
        return approvedTokensIn.contains(token);
    }


    /*
     * @notice View function go determine if Router is approved to be used to buy Portal Token
     * @param router Router address
     * @return Is approved router?
     */
    function isApprovedRouter(address router) external view returns(bool) {
        return approvedRouters.contains(router);
    }


    /*
     * @notice View function go get personal discount
     * @param account Account address
     * @param token ERC20 token address
     * @return Discount in basis points where 10_000 is 100% discount = purchase without fee
     */
    function getPersonalDiscount(address account, address token) public view returns(uint256) {
        Discount[] memory discounts = portals[token].discounts;
        uint256 numberOfDiscounts = discounts.length;

        if (numberOfDiscounts == 0) return 0;

        int256 min = 0;
        int256 max = int256(numberOfDiscounts - 1);

        uint256 burnedTokens = burnedAmount[account][token];

        while (min <= max) {
            uint256 mid = uint256(max + min) / 2;

            if (
                burnedTokens == discounts[mid].burnAmount
                ||
                (burnedTokens > discounts[mid].burnAmount && (mid == numberOfDiscounts - 1))
                ||
                (burnedTokens > discounts[mid].burnAmount && (mid == 0 || burnedTokens < discounts[mid + 1].burnAmount))
            ) {
                return discounts[mid].discount;
            }

            if (discounts[mid].burnAmount > burnedTokens) {
                max = int256(mid) - 1;
            } else {
                min = int256(mid) + 1;
            }
        }

        return 0;
    }


    /*
     * @notice Swaps ERC20 for Tokens
     * @param router V2 Router address
     * @param amountIn Amount tokens to spend
     * @param amountOutMin Minimum amount of tokens to receive
     * @param path Swap path
     * @param deadline Deadline of swap transaction
     * @return amountOut Amount of tokens user has received
     */
    function _buyTokenWithERC20(
        address router,
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        uint256 deadline
    ) private returns(uint256 amountOut) {
        address token = path[path.length - 1];
        if (IERC20(path[0]).allowance(address(this), router) < amountIn) {
            IERC20(path[0]).approve(router, type(uint256).max);
        }

        uint256 initialAmount = IERC20(token).balanceOf(address(this));

        IBabyDogeRouter(router).swapExactTokensForTokensSupportingFeeOnTransferTokens(
            amountIn,
            0,
            path,
            address(this),
            deadline
        );

        amountOut = IERC20(token).balanceOf(address(this)) - initialAmount;
        IERC20(token).safeTransfer(msg.sender, amountOut);
        portals[token].totalBought += amountOut;

        require(amountOut > amountOutMin, "Below amountOutMin");

        emit TokenPurchase(token, msg.sender, amountOut, path[0]);
    }


    /*
     * @notice Checks discounts array for validity
     */
    function _checkDiscounts(Discount[] memory _discounts) private pure {
        require(_discounts.length > 0, "No discount data");
        Discount memory prevDiscount = _discounts[0];
        if (_discounts[0].discount == 0 || _discounts[0].burnAmount == 0 || _discounts[0].discount > 10_000) {
            revert InvalidDiscount(0);
        }
        for(uint i = 1; i < _discounts.length; i++) {
            if (
                _discounts[i].discount == 0
                || prevDiscount.discount >= _discounts[i].discount
                || prevDiscount.burnAmount >= _discounts[i].burnAmount
            ) {
                revert InvalidDiscount(i);
            }
            prevDiscount = _discounts[i];
        }
    }


    /*
     * @notice Sets new discounts values
     * @param token ERC20 token address
     * @param _discounts Array of Discount structs, containing discount amount and burn amount to receive that discount
     */
    function _setDiscounts(address token, Discount[] calldata _discounts) private {
        _checkDiscounts(_discounts);
        delete portals[token].discounts;
        for(uint i = 0; i < _discounts.length; i++) {
            portals[token].discounts.push(_discounts[i]);
        }

        emit DiscountsUpdated(token, _discounts);
    }


    /*
     * @notice Calculates fees for current swap
     * @param tokenOut Address of the token, that is being purchased
     * @param amountIn Amount of tokens IN being spent
     * @return taxAmount Total amount of tax for this swap
     * @return adminFeeAmount Amount of tax that admin fee receiver should receive
     */
    function _getFees(
        address tokenOut,
        uint256 amountIn
    ) private view returns(
        uint256 taxAmount,
        uint256 adminFeeAmount
    ) {
        require(portals[tokenOut].feeReceiver != address(0), "Not active token");
        uint256 personalDiscount = getPersonalDiscount(msg.sender, tokenOut);
        require(personalDiscount > 0, "No discount");
        if (personalDiscount == 10_000) return(0, 0);

        taxAmount = amountIn * portals[tokenOut].baseTax / 10_000 * (10_000 - personalDiscount) / 10_000;
        adminFeeAmount = taxAmount * adminFee / 10_000;
    }
}