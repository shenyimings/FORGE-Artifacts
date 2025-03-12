// SPDX-License-Identifier: MIT
pragma solidity 0.8.0;

import "@openzeppelin/contracts-upgradeable/utils/math/MathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

import "./interfaces/IRebalancer.sol";
import "./interfaces/ICompositePlus.sol";
import "./Plus.sol";

/**
 * @title Composite plus token.
 *
 * A composite plus token is backed by a basket of plus token. The composite plus token,
 * along with its underlying tokens in the basket, should have the same peg.
 */
contract CompositePlus is ICompositePlus, Plus, ReentrancyGuardUpgradeable {
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using SafeMathUpgradeable for uint256;

    event Minted(address indexed user, address[] tokens, uint256[] amounts, uint256 mintShare, uint256 mintAmount);
    event Redeemed(address indexed user, address[] tokens, uint256[] amounts, uint256 redeemShare, uint256 redeemAmount, uint256 fee);

    event RebalancerUpdated(address indexed rebalancer, bool enabled);
    event MinLiquidityRatioUpdated(uint256 oldRatio, uint256 newRatio);
    event TokenAdded(address indexed token);
    event TokenRemoved(address indexed token);
    event Rebalanced(uint256 underlyingBefore, uint256 underlyingAfter, uint256 supply);

    // The underlying plus tokens that constitutes the composite plus token.
    address[] public override tokens;
    // Mapping: Token address => Whether the token is an underlying token.
    mapping(address => bool) public override tokenSupported;
    // Mapping: Token address => Whether minting with token is paused
    mapping(address => bool) public mintPaused;

    // Mapping: Address => Whether this is a rebalancer contract.
    mapping(address => bool) public rebalancers;
    // Liquidity ratio = Total supply / Total underlying
    // Liquidity ratio should larger than 1 in most cases except a short period after rebalance.
    // Minimum liquidity ratio sets the upper bound of impermanent loss caused by rebalance.
    uint256 public minLiquidityRatio;


    /**
     * @dev Initlaizes the composite plus token.
     */
    function initialize(string memory _name, string memory _symbol) public initializer {
        __PlusToken__init(_name, _symbol);
        __ReentrancyGuard_init();
    }

    /**
     * @dev Returns the total value of the plus token in terms of the peg value.
     * All underlying token amounts have been scaled to 18 decimals and expressed in WAD.
     */
    function _totalUnderlyingInWad() internal view virtual override returns (uint256) {
        uint256 _amount = 0;
        for (uint256 i = 0; i < tokens.length; i++) {
            // Since all underlying tokens in the baskets are plus tokens with the same value peg, the amount
            // minted is the amount of all plus tokens in the basket added.
            // Note: All plus tokens, single or composite, have 18 decimals.
            _amount = _amount.add(IERC20Upgradeable(tokens[i]).balanceOf(address(this)));
        }

        // Plus tokens are in 18 decimals, need to return in WAD.
        return _amount.mul(WAD);
    }

    /**
     * @dev Returns the amount of composite plus tokens minted with the tokens provided.
     * @dev _tokens The tokens used to mint the composite plus token.
     * @dev _amounts Amount of tokens used to mint the composite plus token.
     */
    function getMintAmount(address[] calldata _tokens, uint256[] calldata _amounts) external view returns(uint256) {
        require(_tokens.length == _amounts.length, "invalid input");
        uint256 _amount = 0;
        for (uint256 i = 0; i < _tokens.length; i++) {
            require(!mintPaused[_tokens[i]], "token paused");
            require(tokenSupported[_tokens[i]], "token not supported");
            if (_amounts[i] == 0) continue;

            // Since all underlying tokens in the baskets are plus tokens with the same value peg, the amount
            // minted is the amount of all tokens to mint added.
            // Note: All plus tokens, single or composite, have 18 decimals.
            _amount = _amount.add(_amounts[i]);
        }

        return _amount;
    }

    /**
     * @dev Mints composite plus tokens with underlying tokens provided.
     * @dev _tokens The tokens used to mint the composite plus token. The composite plus token must have sufficient allownance on the token.
     * @dev _amounts Amount of tokens used to mint the composite plus token.
     */
    function mint(address[] calldata _tokens, uint256[] calldata _amounts) external override nonReentrant {
        require(_tokens.length == _amounts.length, "invalid input");

        // Rebase first to make index up-to-date
        rebase();
        uint256 _amount = 0;
        for (uint256 i = 0; i < _tokens.length; i++) {
            require(tokenSupported[_tokens[i]], "token not supported");
            require(!mintPaused[_tokens[i]], "token paused");
            if (_amounts[i] == 0) continue;

            _amount = _amount.add(_amounts[i]);
            // Transfers the token into pool.
            IERC20Upgradeable(_tokens[i]).safeTransferFrom(msg.sender, address(this), _amounts[i]);
        }

        uint256 _share = _amount.mul(WAD).div(index);
        uint256 _oldShare = userShare[msg.sender];
        uint256 _newShare = _oldShare.add(_share);
        uint256 _totalShares = totalShares.add(_share);
        totalShares = _totalShares;
        userShare[msg.sender] = _newShare;

        emit UserShareUpdated(msg.sender, _oldShare, _newShare, _totalShares);
        emit Minted(msg.sender, _tokens, _amounts, _share, _amount);
    }

    /**
     * @dev Returns the amount of tokens received in redeeming the composite plus token.
     * @param _amount Amounf of composite plus to redeem.
     * @return Addresses and amounts of tokens returned as well as fee collected.
     */
    function getRedeemAmount(uint256 _amount) external view returns (address[] memory, uint256[] memory, uint256, uint256) {
        require(_amount > 0, "zero amount");

        // Special handling of -1 is required here in order to fully redeem all shares, since interest
        // will be accrued between the redeem transaction is signed and mined.
        uint256 _share;
        if (_amount == uint256(int256(-1))) {
            _share = userShare[msg.sender];
            _amount = _share.mul(index).div(WAD);
        } else {
            _share  = _amount.mul(WAD).div(index);
        }

        // Withdraw ratio = min(liquidity ratio, 1 - redeem fee)
        // Liquidity ratio is in WAD and redeem fee is in 0.01%
        uint256 _withdrawAmount1 = _amount.mul(liquidityRatio()).div(WAD);
        uint256 _withdrawAmount2 = _amount.mul(MAX_PERCENT - redeemFee).div(MAX_PERCENT);
        uint256 _withdrawAmount = MathUpgradeable.min(_withdrawAmount1, _withdrawAmount2);
        uint256 _fee = _amount.sub(_withdrawAmount);

        address[] memory _redeemTokens = tokens;
        uint256[] memory _redeemAmounts = new uint256[](_redeemTokens.length);
        uint256 _totalSupply = totalSupply();
        for (uint256 i = 0; i < _redeemTokens.length; i++) {
            uint256 _balance = IERC20Upgradeable(_redeemTokens[i]).balanceOf(address(this));
            if (_balance == 0)   continue;

            _redeemAmounts[i] = _balance.mul(_withdrawAmount).div(_totalSupply);
        }

        return (_redeemTokens, _redeemAmounts, _share, _fee);
    }

    /**
     * @dev Redeems the composite plus token. In the current implementation only proportional redeem is supported.
     * @param _amount Amount of composite plus token to redeem. -1 means redeeming all shares.
     */
    function redeem(uint256 _amount) external override nonReentrant {
        require(_amount > 0, "zero amount");

        // Rebase first to make index up-to-date
        rebase();

        // Special handling of -1 is required here in order to fully redeem all shares, since interest
        // will be accrued between the redeem transaction is signed and mined.
        uint256 _share;
        if (_amount == uint256(int256(-1))) {
            _share = userShare[msg.sender];
            _amount = _share.mul(index).div(WAD);
        } else {
            _share  = _amount.mul(WAD).div(index);
        }

        // Withdraw ratio = min(liquidity ratio, 1 - redeem fee)
        uint256 _withdrawAmount1 = _amount.mul(liquidityRatio()).div(WAD);
        uint256 _withdrawAmount2 = _amount.mul(MAX_PERCENT - redeemFee).div(MAX_PERCENT);
        uint256 _withdrawAmount = MathUpgradeable.min(_withdrawAmount1, _withdrawAmount2);
        uint256 _fee = _amount.sub(_withdrawAmount);

        address[] memory _redeemTokens = tokens;
        uint256[] memory _redeemAmounts = new uint256[](_redeemTokens.length);
        uint256 _totalSupply = totalSupply();
        for (uint256 i = 0; i < _redeemTokens.length; i++) {
            uint256 _balance = IERC20Upgradeable(_redeemTokens[i]).balanceOf(address(this));
            if (_balance == 0)   continue;

            _redeemAmounts[i] = _balance.mul(_withdrawAmount).div(_totalSupply);
            IERC20Upgradeable(_redeemTokens[i]).safeTransfer(msg.sender, _redeemAmounts[i]);
        }

        // Updates the balance
        uint256 _oldShare = userShare[msg.sender];
        uint256 _newShare = _oldShare.sub(_share);
        totalShares = totalShares.sub(_share);
        userShare[msg.sender] = _newShare;

        emit UserShareUpdated(msg.sender, _oldShare, _newShare, totalShares);
        emit Redeemed(msg.sender, _redeemTokens, _redeemAmounts, _share, _amount, _fee);
    }

    /**
     * @dev Updates the mint paused state of a token.
     * @param _token Token to update mint paused.
     * @param _paused Whether minting with that token is paused.
     */
    function setMintPaused(address _token, bool _paused) external onlyStrategist {
        require(tokenSupported[_token], "not supported");
        require(mintPaused[_token] != _paused, "no change");

        mintPaused[_token] = _paused;
        emit MintPausedUpdated(_token, _paused);
    }

    /**
     * @dev Adds a new rebalancer. Only governance can add new rebalancers.
     */
    function addRebalancer(address _rebalancer) external onlyGovernance {
        require(_rebalancer != address(0x0), "rebalancer not set");
        require(!rebalancers[_rebalancer], "rebalancer exist");

        rebalancers[_rebalancer] = true;
        emit RebalancerUpdated(_rebalancer, true);
    }

    /**
     * @dev Remove an existing rebalancer. Only strategist can remove existing rebalancers.
     */
    function removeRebalancer(address _rebalancer) external onlyStrategist {
        require(rebalancers[_rebalancer], "rebalancer exist");

        rebalancers[_rebalancer] = false;
        emit RebalancerUpdated(_rebalancer, false);
    }

    /**
     * @dev Udpates the minimum liquidity ratio. Only governance can update minimum liquidity ratio.
     */
    function setMinLiquidityRatio(uint256 _minLiquidityRatio) external onlyGovernance {
        require(_minLiquidityRatio <= WAD, "overflow");
        require(_minLiquidityRatio <= liquidityRatio(), "ratio too big");
        uint256 _oldRatio = minLiquidityRatio;

        minLiquidityRatio = _minLiquidityRatio;
        emit MinLiquidityRatioUpdated(_oldRatio, _minLiquidityRatio);
    }

    /**
     * @dev Adds a new plus token to the basket. Only governance can add new plus token.
     * @param _token The new plus token to add.
     */
    function addToken(address _token) external onlyGovernance {
        require(_token != address(0x0), "token not set");
        require(!tokenSupported[_token], "token exists");

        tokenSupported[_token] = true;
        tokens.push(_token);

        emit TokenAdded(_token);
    }

    /**
     * @dev Removes a plus token from the basket. Only governance can remove a plus token.
     * Note: A token cannot be removed if it's balance is not zero!
     * @param _token The plus token to remove from the basket.
     */
    function removeToken(address _token) external onlyGovernance {
        require(tokenSupported[_token], "token not exists");
        require(IERC20Upgradeable(_token).balanceOf(address(this)) == 0, "nonzero balance");

        uint256 _tokenSize = tokens.length;
        uint256 _tokenIndex = _tokenSize;
        for (uint256 i = 0; i < _tokenSize; i++) {
            if (tokens[i] == _token) {
                _tokenIndex = i;
                break;
            }
        }
        // We must have found the token!
        assert(_tokenIndex < _tokenSize);

        tokens[_tokenIndex] = tokens[_tokenSize - 1];
        tokens.pop();
        delete tokenSupported[_token];
        // Delete the mint paused state as well
        delete mintPaused[_token];

        emit TokenRemoved(_token);
    }

    /**
     * @dev Return the total number of tokens.
     */
    function tokenSize() external view returns (uint256) {
        return tokens.length;
    }

    /**
     * @dev Rebalances the basket, e.g. for a better yield. Only strategist can perform rebalance.
     * @param _tokens Address of the tokens to withdraw from the basket.
     * @param _amounts Amounts of the tokens to withdraw from the basket.
     * @param _rebalancer Address of the rebalancer contract to invoke.
     * @param _data Data to invoke on rebalancer contract.
     */
    function rebalance(address[] memory _tokens, uint256[] memory _amounts, address _rebalancer, bytes calldata _data) external onlyStrategist {
        require(rebalancers[_rebalancer], "invalid rebalancer");
        require(_tokens.length == _amounts.length, "invalid input");

        // Rebase first to make index up-to-date
        rebase();
        uint256 _underlyingBefore = _totalUnderlyingInWad();

        for (uint256 i = 0; i < _tokens.length; i++) {
            require(tokenSupported[_tokens[i]], "token not supported");
            if (_amounts[i] == 0)   continue;

            IERC20Upgradeable(_tokens[i]).safeTransfer(_rebalancer, _amounts[i]);
        }
        // Invokes rebalancer contract.
        IRebalancer(_rebalancer).rebalance(_tokens, _amounts, _data);

        // Check post-rebalance conditions.
        uint256 _underlyingAfter = _totalUnderlyingInWad();
        uint256 _supply = totalSupply();
        // _underlyingAfter / _supply > minLiquidityRatio
        require(_underlyingAfter > _supply.mul(minLiquidityRatio), "too much loss");

        emit Rebalanced(_underlyingBefore, _underlyingAfter, _supply);
    }

    /**
     * @dev Checks whether a token can be salvaged via salvageToken().
     * @param _token Token to check salvageability.
     */
    function _salvageable(address _token) internal view override returns (bool) {
        // For composite plus, all tokens in the basekt cannot be salvaged!
        return !tokenSupported[_token];
    }

    uint256[50] private __gap;
}
