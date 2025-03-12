pragma solidity ^0.5.16;
pragma experimental ABIEncoderV2;

import "./PriceOracle.sol";
import "./WBep20.sol";
import "./BEP20Interface.sol";
import "./SafeMath.sol";

interface IStdReference {
    /// A structure returned whenever someone requests for standard reference data.
    struct ReferenceData {
        uint256 rate; // base/quote exchange rate, multiplied by 1e18.
        uint256 lastUpdatedBase; // UNIX epoch of the last time when base price gets updated.
        uint256 lastUpdatedQuote; // UNIX epoch of the last time when quote price gets updated.
    }

    /// Returns the price data for the given base/quote pair. Revert if not available.
    function getReferenceData(string calldata _base, string calldata _quote) external view returns (ReferenceData memory);

    /// Similar to getReferenceData, but with multiple base/quote pairs at once.
    function getReferenceDataBulk(string[] calldata _bases, string[] calldata _quotes) external view returns (ReferenceData[] memory);
}


interface IPancakeRouter {
    function getAmountsOut(uint256 amountIn, address[] calldata path)
        external
        view
        returns (uint256[] memory amounts);
}

contract WelPriceOracle is PriceOracle {
    using SafeMath for uint256;
    address public routerAddress = 0x9Ac64Cc6e4415144C455BD8E4837Fea55603e5c3;
    address public admin;
    address public tokenBUSD;
    address public tokenWel;

    mapping(address => uint) prices;
    event PricePosted(address asset, uint previousPriceMantissa, uint requestedPriceMantissa, uint newPriceMantissa);
    event NewAdmin(address oldAdmin, address newAdmin);

    IStdReference ref;

    constructor(IStdReference _ref) public {
        ref = _ref;
        admin = msg.sender;
    }

    function getAmountsOut(uint256 _amountIn, address token0, address token1) public view returns (uint256 result) {
        address[] memory pairToken = new address[](2);
        pairToken[0] = token0;
        pairToken[1] = token1;
        uint256[] memory results = IPancakeRouter(routerAddress).getAmountsOut(_amountIn, pairToken);
        result = results[1];
    }

    function setTokenBUSD (address _tokenAddress) external {
        tokenBUSD = _tokenAddress;
    }
    
    function setTokenWel (address _tokenAddress) external {
        tokenWel = _tokenAddress;
    }

    function getUnderlyingPrice(WLToken wlToken) public view returns (uint) {
        if (compareStrings(wlToken.symbol(), "wlWEL")) {
            return getAmountsOut(1000000000000000000,tokenWel, tokenBUSD);
        } else if (compareStrings(wlToken.symbol(), "wlBNB")) {
            IStdReference.ReferenceData memory data = ref.getReferenceData("BNB", "USD");
            return data.rate;
        } else {
            uint256 price;
            BEP20Interface token = BEP20Interface(WBep20(address(wlToken)).underlying());

            if(prices[address(token)] != 0) {
                price = prices[address(token)];
            } else {
                IStdReference.ReferenceData memory data = ref.getReferenceData(token.symbol(), "USD");
                price = data.rate;
            }

            uint decimalDelta = 18-uint(token.decimals());
            return price.mul(10**decimalDelta);
        }
    }

    function setUnderlyingPrice(WLToken wlToken, uint underlyingPriceMantissa) public {
        require(msg.sender == admin, "only admin can set underlying price");
        address asset = address(WBep20(address(wlToken)).underlying());
        emit PricePosted(asset, prices[asset], underlyingPriceMantissa, underlyingPriceMantissa);
        prices[asset] = underlyingPriceMantissa;
    }

    function setDirectPrice(address asset, uint price) public {
        require(msg.sender == admin, "only admin can set price");
        emit PricePosted(asset, prices[asset], price, price);
        prices[asset] = price;
    }

    function assetPrices(address asset) external view returns (uint) {
        return prices[asset];
    }

    function compareStrings(string memory a, string memory b) internal pure returns (bool) {
        return (keccak256(abi.encodePacked((a))) == keccak256(abi.encodePacked((b))));
    }

    function setAdmin(address newAdmin) external {
        require(msg.sender == admin, "only admin can set new admin");
        address oldAdmin = admin;
        admin = newAdmin;

        emit NewAdmin(oldAdmin, newAdmin);
    }
}
