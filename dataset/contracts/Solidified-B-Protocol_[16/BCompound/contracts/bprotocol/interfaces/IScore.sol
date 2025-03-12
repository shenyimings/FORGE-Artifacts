pragma solidity 0.5.16;

interface IScore {
    function updateDebtScore(address _user, address cToken, int256 amount) external;
    function updateCollScore(address _user, address cToken, int256 amount) external;
    function slashedScore(address _user, address cToken, int256 amount) external;
}