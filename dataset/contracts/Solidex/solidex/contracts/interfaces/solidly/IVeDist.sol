pragma solidity 0.8.11;

interface IVeDist {
    function claim(uint _tokenId) external returns (uint);
}
