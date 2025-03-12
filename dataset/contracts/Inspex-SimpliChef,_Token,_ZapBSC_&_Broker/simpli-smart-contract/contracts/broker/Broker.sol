pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./token/SafeBEP20.sol";
import "./interfaces/IBEP20.sol";
import "./interfaces/IPancakePair.sol";
import "./interfaces/IPancakeRouter02.sol";
import "./interfaces/ISimplichef.sol";
import "./interfaces/IZap.sol";
import "./interfaces/IWBNB.sol";

contract Broker {
    using SafeMath for uint256;
    using SafeBEP20 for IBEP20;

    event Deposit(address indexed sender, uint amount, uint balance);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);

    IZap public zap;
    ISimplichef public simplichef;

    address private constant WBNB = 0xae13d989daC2f0dEbFf460aC112a837C89BAa7cd; // testnet

    constructor (IZap _zap, ISimplichef _simplichef) {
        zap = _zap;
        simplichef = _simplichef;
    }

    receive() external payable {
        emit Deposit(msg.sender, msg.value, address(this).balance);
    }

    function _approveTokenForZap(address token) private {
        if (IBEP20(token).allowance(address(this), address(zap)) == 0) {
            IBEP20(token).safeApprove(address(zap), type(uint256).max);
        }
    }

    function _approveTokenForSimpliChef(address token) private {
        if (IBEP20(token).allowance(address(this), address(simplichef)) == 0) {
            IBEP20(token).safeApprove(address(simplichef), type(uint256).max);
        }
    }

    function _approveTokenForBroker(address token) private {
        if (IBEP20(token).allowance(address(this), address(simplichef)) == 0) {
            IBEP20(token).safeApprove(address(simplichef), type(uint256).max);
        }
    }


    // zapAndDeposit
    function zapInTokenAndDeposit(
        address _from,
        uint256[] memory _amounts,
        address[] memory _to,
        uint256[] memory _pid,
        address _beneficiary
    ) external {
        require(_amounts.length == _to.length, "Amount and address lengths don't match");
        require(_to.length == _pid.length, "Address and pid lengths don't match");
        _approveTokenForZap(_from);
        uint256 sumAmount = 0;
        for (uint256 i=0; i < _amounts.length; i++){
            sumAmount = sumAmount.add(_amounts[i]);
        }
        IBEP20(_from).safeTransferFrom(msg.sender, address(this), sumAmount);
        for (uint256 i=0; i < _amounts.length; i++) {
            (, , uint256 LPAmount) = zap.zapInToken(_from, _amounts[i], _to[i]);
            _approveTokenForSimpliChef(_to[i]);
            simplichef.depositOnlyBroker(_pid[i], LPAmount, _beneficiary);
        }
    }

    function zapInBNBAndDeposit(
        uint256[] memory _amounts,
        address[] memory _to,
        uint256[] memory _pid,
        address _beneficiary
    ) external payable {
        require(_amounts.length == _to.length, "Amount and address lengths don't match");
        require(_to.length == _pid.length, "Address and pid lengths don't match");
        for (uint256 i=0; i < _amounts.length; i++) {
            (, , uint256 LPAmount) = zap.zapIn{value : _amounts[i]}(_to[i]);
            _approveTokenForSimpliChef(_to[i]);
            simplichef.depositOnlyBroker(_pid[i], LPAmount, _beneficiary);
        }
    }

    function withdrawAndZapOut(
        address _to,
        uint256[] memory _pid,
        uint256[] memory _amounts
    ) external {
        require(_pid.length == _amounts.length, "Address and pid lengths don't match");
        uint256 totalAmount = 0;
        for (uint256 i=0; i < _amounts.length; i++) {
            uint256 LPAmount = simplichef.withdrawOnlyBroker(_pid[i], _amounts[i], msg.sender);
            address from = simplichef.poolAddress(_pid[i]);
            _approveTokenForZap(from);
            totalAmount = totalAmount.add(zap.zapOutToToken(from, LPAmount, _to));
        }
        if (_to == WBNB) {
            IWBNB(_to).withdraw(totalAmount);
            (bool sent, ) = msg.sender.call{ value: totalAmount }("");
            require(sent, "Failed to send BNB");
        } else {
            IBEP20(_to).safeTransfer(msg.sender, totalAmount);
        }
    }
}
