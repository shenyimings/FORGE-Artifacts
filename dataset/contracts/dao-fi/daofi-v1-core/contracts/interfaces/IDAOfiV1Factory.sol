// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity =0.7.4;
pragma experimental ABIEncoderV2;

interface IDAOfiV1Factory {
    event PairCreated(
        address indexed baseToken,
        address indexed quoteToken,
        address pairOwner,
        uint32 slopeNumerator,
        uint32 n,
        uint32 fee,
        address pair,
        uint length
    );
    function formula() external view returns (address);
    function pairs(bytes32 hashedParams) external view returns (address);
    function getPair(
        address baseToken,
        address quoteToken,
        uint32 slopeNumerator,
        uint32 n,
        uint32 fee
    ) external view returns (address pair);
    function allPairs(uint) external view returns (address pair);
    function allPairsLength() external view returns (uint);
    function createPair(
        address router,
        address baseToken,
        address quoteToken,
        address pairOwner,
        uint32 slopeNumerator,
        uint32 n,
        uint32 fee
    ) external returns (address pair);
}
