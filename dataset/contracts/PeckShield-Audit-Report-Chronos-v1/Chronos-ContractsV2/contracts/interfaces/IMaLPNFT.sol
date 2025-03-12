// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

interface IMaLPNFT {
  

  function addGauge ( address _maGaugeAddress, address _pool, address _token0, address _token1, uint _maGaugeId ) external;
  function approve ( address _approved, uint256 _tokenId ) external;
  function artProxy (  ) external view returns ( address );
  function balanceOf ( address _owner ) external view returns ( uint256 );
  function burn ( uint256 _tokenId ) external;
  function getApproved ( uint256 _tokenId ) external view returns ( address );
  function initialize ( address art_proxy ) external;
  function isApprovedForAll ( address _owner, address _operator ) external view returns ( bool );
  function isApprovedOrOwner ( address _spender, uint256 _tokenId ) external view returns ( bool );
  function killGauge ( address _gauge ) external;
  function maGauges ( address ) external view returns (
    bool active,
    bool stablePair,
    address pair,
    address token0,
    address token1,
    address maGaugeAddress,
    string memory name,
    string memory symbol,
    uint maGaugeId
  );
  function mint ( address _to ) external returns ( uint256 _tokenId );
  function ms (  ) external view returns ( address );
  function name (  ) external view returns ( string memory );
  function ownerOf ( uint256 _tokenId ) external view returns ( address );
  function ownership_change ( uint256 ) external view returns ( uint256 );
  function reset (  ) external;
  function reviveGauge ( address _gauge ) external;
  function maGaugeTokensOfOwner(address _owner, address _gauge) external view returns (uint256[] memory);
  function fromThisGauge(uint _tokenId) external view returns(bool);
  function safeTransferFrom ( address _from, address _to, uint256 _tokenId ) external;
  function safeTransferFrom ( address _from, address _to, uint256 _tokenId, bytes memory _data  ) external;
  function setApprovalForAll ( address _operator, bool _approved ) external;
  function setArtProxy ( address _proxy ) external;
  function setBoostParams ( uint256 _maxBonusEpoch, uint256 _maxBonusPercent ) external;
  function setTeam ( address _team ) external;
  function supportsInterface ( bytes4 _interfaceID ) external view returns ( bool );
  function symbol (  ) external view returns ( string memory );
  function team (  ) external view returns ( address );
  function getWeightByEpoch() external view returns (uint[] memory weightsByEpochs);
  function totalMaLevels() external view returns (uint _totalMaLevels);
  function tokenOfOwnerByIndex ( address _owner, uint256 _tokenIndex ) external view returns ( uint256 );
  function tokenToGauge ( uint256 ) external view returns ( address );
  function tokenURI ( uint256 _tokenId ) external view returns ( string memory );
  function transferFrom ( address _from, address _to, uint256 _tokenId ) external;
  function version (  ) external view returns ( string memory );
  function voter (  ) external view returns ( address );
}
