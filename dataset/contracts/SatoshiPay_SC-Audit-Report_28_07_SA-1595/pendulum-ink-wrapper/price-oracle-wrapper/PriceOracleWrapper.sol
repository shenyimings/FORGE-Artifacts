// This file does not define a pragma version because it is meant to be compiled with Solang and Solang ignores
// pragma definitions, see [here](https://solang.readthedocs.io/en/latest/language/pragmas.html).

import "polkadot";
import {IPriceOracleGetter} from "./interfaces/IPriceOracleGetter.sol";

/**
 * @title PriceOracleWrapper
 * @notice Price oracle that uses the native chain via chain extension. It stores _asset, _blockchain and _symbol for use by function getAssetPrice() which is called by Nabla. 
 * @dev This contract can be used with the Nabla's Router contract
 */
contract PriceOracleWrapper is IPriceOracleGetter {
    // The coin info returned by the chain extension call
    struct CoinInfo {
        bytes symbol;
        bytes name;
        bytes blockchain;
        uint128 supply;
        uint64 last_update_timestamp;
        uint128 price;
    }

    // The mapping of an asset address with the oracles keys blockchain and symbol
    struct OracleKey {
        address asset;
        string blockchain;
        string symbol;
    }

    mapping(address => OracleKey) public oracleByAsset;

    // we store _asset, _blockchain and _symbol for use by function getAssetPrice() which is called by Nabla. 
    // _blockchain and _symbol are the keys used to access a particular price feed from the chain.
    constructor(OracleKey[] oracleKeys) {
        uint oracleKeysLength = oracleKeys.length;
        for (uint i = 0; i < oracleKeysLength; i++) {
            oracleByAsset[oracleKeys[i].asset] = oracleKeys[i];
        }
    }

    function getOracleKeyAsset(address asset) external view returns (address) {
        return oracleByAsset[asset].asset;
    }

    function getOracleKeyBlockchain(address asset) external view returns (string) {
        return oracleByAsset[asset].blockchain;
    }

    function getOracleKeySymbol(address asset) external view returns (string) {
        return oracleByAsset[asset].symbol;
    }

    /**
     * @notice Returns the asset price in USD. This is called by Nabla and expected by their IPriceOracleGetter interface
     * @param asset asset address
     * @return price Asset price in USD
     */
    function getAssetPrice(address asset) external returns (uint256 price) {
        require(oracleByAsset[asset].asset == asset, "Asset not supported");
        price = uint256(getAnyAssetPrice(oracleByAsset[asset].blockchain, oracleByAsset[asset].symbol));
    }

    function getAnyAssetSupply(string blockchain, string symbol) external returns (uint128 result) {
        result = getAnyAsset(blockchain, symbol).supply;
    }

    function getAnyAssetLastUpdateTimestamp(string blockchain, string symbol) external returns (uint64 result) {
        result = getAnyAsset(blockchain, symbol).last_update_timestamp;
    }

    function getAnyAssetPrice(string blockchain, string symbol) public returns (uint128 result) {
        result = getAnyAsset(blockchain, symbol).price;
    }

    /**
     * @notice performs the actual chain extension call to get the price feed. blockchain and symbol are the keys used to access a particular price feed from the chain.
     * @param blockchain input string
     * @param symbol input string
     * @return result the struct containing all the coin info
     */
    function getAnyAsset(string blockchain, string symbol) public returns (CoinInfo result) {
        bytes input = abi.encodePacked(stringToBytes32(blockchain), stringToBytes32(symbol));
        (uint32 result_chain_ext, bytes raw_data) = chain_extension((2 << 16) + 1200, input);
        require(result_chain_ext == 0, "Call to chain_extension failed.");

        // Since a Rust Result<CoinInfo, Error> is returned, we need to check if it was Ok/Err. 0 is Ok, which means the rest is a CoinInfo
        require(raw_data[0] == 0, "Chain extension call returned an error.");
        (uint8 _, CoinInfo coinInfo) = abi.decode(raw_data, (uint8, CoinInfo));
        result = coinInfo;
    }

    /**
     * @notice converts a string to a bytes of length 32. Will truncate the string or pad with null values to fit the bytes of length 32. This output is the expected format for blockchain and symbol.
     * @param str input string
     * @return result32 a bytes of length 32
     */
    function stringToBytes32(string str) private pure returns (bytes result32){
        bytes input = bytes(str);
        bytes output = new bytes(32);
        for (uint i = 0; i < output.length && i < input.length; i++) {
            output[i] = bytes(input)[i];
        }
        result32 = output;
    }

    
}
