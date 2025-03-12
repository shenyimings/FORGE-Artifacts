pragma solidity 0.7.4;
import "../interfaces/ISkyweaverAssets.sol";

contract FactoryMock {

  ISkyweaverAssets internal skyweaverAssets; //SkyWeaver Curencies Factory Manager Contract

  constructor(address _factoryManagerAddr) public {
    skyweaverAssets = ISkyweaverAssets(_factoryManagerAddr);
  }

  function batchMint(
    address _to,
    uint256[] memory _ids,
    uint256[] memory _amounts,
    bytes memory _data) public
  {
    skyweaverAssets.batchMint(_to, _ids, _amounts, _data);
  }

  function mint(
    address _to,
    uint256 _id,
    uint256 _amount,
    bytes memory _data) public
  {
    skyweaverAssets.mint(_to, _id, _amount, _data);
  }

}