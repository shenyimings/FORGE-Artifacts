pragma solidity 0.8.7;

/// @dev this is the one contract call that the OTC needs to interact with the NFT contract
interface INFT {
  function createNFT(
    address _holder,
    uint256 _amount,
    address _token,
    uint256 _unlockDate
  ) external returns (uint256);
}
