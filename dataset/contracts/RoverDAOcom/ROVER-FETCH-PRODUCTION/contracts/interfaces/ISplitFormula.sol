interface ISplitFormula{
  function calculateToSplit(uint256 ethInput)
    external
    view
    returns(uint256 ethTodex, uint256 ethToSale);
}
