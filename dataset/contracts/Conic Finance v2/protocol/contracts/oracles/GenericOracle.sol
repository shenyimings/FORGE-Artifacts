// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import "../../libraries/ScaledMath.sol";
import "../../interfaces/IGenericOracle.sol";

contract GenericOracle is IGenericOracle, Ownable {
    using ScaledMath for uint256;

    event CustomOracleAdded(address token, address oracle);

    mapping(address => IOracle) public customOracles;

    IOracle internal _chainlinkOracle;
    IOracle internal _curveLpOracle;

    function initialize(address curveLpOracle, address chainlinkOracle) external {
        require(address(_curveLpOracle) == address(0), "already initialized");
        _chainlinkOracle = IOracle(chainlinkOracle);
        _curveLpOracle = IOracle(curveLpOracle);
    }

    function isTokenSupported(address token) external view override returns (bool) {
        return
            address(customOracles[token]) != address(0) ||
            _chainlinkOracle.isTokenSupported(token) ||
            _curveLpOracle.isTokenSupported(token);
    }

    function getUSDPrice(address token) public view virtual returns (uint256) {
        if (_chainlinkOracle.isTokenSupported(token)) {
            return _chainlinkOracle.getUSDPrice(token);
        }
        if (address(customOracles[token]) != address(0)) {
            return customOracles[token].getUSDPrice(token);
        }
        return _curveLpOracle.getUSDPrice(token);
    }

    function setCustomOracle(address token, address oracle) external onlyOwner {
        customOracles[token] = IOracle(oracle);
        emit CustomOracleAdded(token, oracle);
    }

    function curveLpToUnderlying(
        address curveLpToken,
        address underlying,
        uint256 curveLpAmount
    ) external view returns (uint256) {
        return
            curveLpToUnderlying(curveLpToken, underlying, curveLpAmount, getUSDPrice(underlying));
    }

    function curveLpToUnderlying(
        address curveLpToken,
        address underlying,
        uint256 curveLpAmount,
        uint256 underlyingPrice
    ) public view returns (uint256) {
        return
            curveLpAmount.mulDown(getUSDPrice(curveLpToken)).divDown(underlyingPrice).convertScale(
                18,
                IERC20Metadata(underlying).decimals()
            );
    }

    function underlyingToCurveLp(
        address underlying,
        address curveLpToken,
        uint256 underlyingAmount
    ) external view returns (uint256) {
        return
            underlyingAmount
                .mulDown(getUSDPrice(address(underlying)))
                .divDown(getUSDPrice(curveLpToken))
                .convertScale(IERC20Metadata(underlying).decimals(), 18);
    }
}
