// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.5.17;

import "./Impl/ChainlinkPriceOracle.sol";

contract RinkarbyPriceOracle is L2ChainlinkPriceOracle {
    constructor() public {
        chainlinkDataFeeds[0x8909023C6323b61C9Ce6eB11049044e07E5b7F03] = 0x0c9973e7a27d00e656B9f153348dA46CaD70d03d; // wbtc
        chainlinkDataFeeds[0xc25784BEcEceb73109d7e822e857C1cF86df9160] = 0x5f0423B1a6935dc5596e7A24d98532b67A0AeFd8; // weth
        stablecoinsPrices[0x8950258664ccDA7293521D1c95497657Fd4C483A] = 1000000000000000000; // usdc == 1 USD
        stablecoinsPrices[0x233C58828A9433d76C5b221a99a936a3a45781B7] = 1000000000000000000; // usdt == 1 USD
        pEtherAddress = address(0);

        chainlinkFlags = FlagsInterface(0x491B1dDA0A8fa069bbC1125133A975BF4e85a91b);
        FLAG_SEQ_OFFLINE = address(bytes20(bytes32(uint256(keccak256("chainlink.flags.arbitrum-seq-offline")) - 1)));
    }
}

contract ArbitrumPriceOracle is L2ChainlinkPriceOracle {
    constructor() public {
        chainlinkDataFeeds[address(0)] = 0x6ce185860a4963106506C203335A2910413708e9; // wbtc
        chainlinkDataFeeds[address(0)] = 0x639Fe6ab55C921f74e7fac1ee960C0B6293ba612; // eth
        chainlinkDataFeeds[address(0)] = 0x639Fe6ab55C921f74e7fac1ee960C0B6293ba612; // weth
        chainlinkDataFeeds[address(0)] = 0xc5C8E77B397E531B8EC06BFb0048328B30E9eCfB; // dai
        stablecoinsPrices[address(0)] = 1000000000000000000000000000000; // usdc == 1 USD
        pEtherAddress = address(0);

        chainlinkFlags = FlagsInterface(0x3C14e07Edd0dC67442FA96f1Ec6999c57E810a83);
        FLAG_SEQ_OFFLINE = address(bytes20(bytes32(uint256(keccak256("chainlink.flags.arbitrum-seq-offline")) - 1)));
    }
}
