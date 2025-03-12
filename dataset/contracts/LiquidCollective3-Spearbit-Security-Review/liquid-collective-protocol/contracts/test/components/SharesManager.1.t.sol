//SPDX-License-Identifier: MIT

pragma solidity 0.8.10;

import "forge-std/Test.sol";

import "../utils/UserFactory.sol";
import "../utils/LibImplementationUnbricker.sol";

import "../../src/components/SharesManager.1.sol";

contract SharesManagerPublicDeal is SharesManagerV1 {
    uint256 public totalBalance;

    error Denied(address _account);

    mapping(address => bool) internal denied;

    function setDenied(address _account) external {
        denied[_account] = true;
    }

    function _onTransfer(address _from, address _to) internal view override {
        if (denied[_from]) {
            revert Denied(_from);
        }
        if (denied[_to]) {
            revert Denied(_to);
        }
    }

    function setValidatorBalance(uint256 _amount) external {
        totalBalance = _amount;
    }

    function _assetBalance() internal view override returns (uint256) {
        return totalBalance + address(this).balance;
    }

    function deal(address _owner, uint256 _amount) external {
        uint256 shares = SharesPerOwner.get(_owner);
        Shares.set(Shares.get() - shares);
        SharesPerOwner.set(_owner, SharesPerOwner.get(_owner) - shares);

        Shares.set(Shares.get() + _amount);
        SharesPerOwner.set(_owner, _amount);
    }

    function mint(address _owner, uint256 _amount) external {
        SharesManagerV1._mintShares(_owner, _amount);
    }

    fallback() external payable {}

    receive() external payable {}
}

contract SharesManagerV1Tests is Test {
    UserFactory internal uf = new UserFactory();

    SharesManagerV1 internal sharesManager;

    error Denied(address _account);

    event SetTotalSupply(uint256 totalSupply);

    function setUp() public {
        sharesManager = new SharesManagerPublicDeal();
        LibImplementationUnbricker.unbrick(vm, address(sharesManager));
    }

    function testBalanceOfUnderlying(uint256 _userSalt) public {
        address _user = uf._new(_userSalt);
        SharesManagerPublicDeal(payable(address(sharesManager))).setValidatorBalance(3200 ether);
        assert(sharesManager.balanceOf(_user) == 0);

        uint256 shares = sharesManager.totalSupply();
        uint256 supply = sharesManager.totalUnderlyingSupply();

        SharesManagerPublicDeal(payable(address(sharesManager))).deal(_user, 10 ether);

        uint256 expectedBalance = (supply * 10 ether) / (shares + 10 ether);

        assert(sharesManager.balanceOfUnderlying(_user) == expectedBalance);
    }

    function testBalanceOf(uint256 _userSalt, uint256 _anotherUserSalt) public {
        address _user = uf._new(_userSalt);
        address _anotherUser = uf._new(_anotherUserSalt);
        assert(sharesManager.balanceOf(_user) == 0);
        SharesManagerPublicDeal(payable(address(sharesManager))).deal(_user, 10 ether);
        assert(sharesManager.balanceOf(_user) == 10 ether);

        SharesManagerPublicDeal(payable(address(sharesManager))).setValidatorBalance(300 ether);
        assert(sharesManager.balanceOf(_user) == 10 ether);

        assert(sharesManager.balanceOf(_anotherUser) == 0 ether);
        vm.startPrank(_user);
        sharesManager.transfer(_anotherUser, 10 ether);
        assert(sharesManager.balanceOf(_anotherUser) == 10 ether);
        assert(sharesManager.balanceOf(_user) == 0 ether);
    }

    function testBalanceOfMultiRebasings(uint256 _userSalt, uint256 _anotherUserSalt) public {
        address _user = uf._new(_userSalt);
        address _anotherUser = uf._new(_anotherUserSalt);
        _anotherUser = address(uint160(_user) + 1);
        SharesManagerPublicDeal(payable(address(sharesManager))).setValidatorBalance(0 ether);

        assert(sharesManager.balanceOf(_user) == 0);

        SharesManagerPublicDeal(payable(address(sharesManager))).setValidatorBalance(300 ether);
        SharesManagerPublicDeal(payable(address(sharesManager))).mint(_user, 300 ether);

        assert(sharesManager.balanceOf(_user) == 300 ether);

        SharesManagerPublicDeal(payable(address(sharesManager))).setValidatorBalance(440 ether);
        SharesManagerPublicDeal(payable(address(sharesManager))).mint(_anotherUser, 100 ether);

        assert(sharesManager.balanceOf(_user) == 300 ether);
        assert(sharesManager.balanceOf(_anotherUser) == 88235294117647058823);

        assert(sharesManager.balanceOfUnderlying(_user) == 340 ether);
        assert(sharesManager.balanceOfUnderlying(_anotherUser) == 99999999999999999999); // rounding issues with solidity, diff is negligible
    }

    function testTotalSupplyEvent(uint256 _userSalt, uint256 _anotherUserSalt) public {
        address _user = uf._new(_userSalt);
        address _anotherUser = uf._new(_anotherUserSalt);
        _anotherUser = address(uint160(_user) + 1);
        SharesManagerPublicDeal(payable(address(sharesManager))).setValidatorBalance(0 ether);

        assert(sharesManager.balanceOf(_user) == 0);

        SharesManagerPublicDeal(payable(address(sharesManager))).setValidatorBalance(300 ether);
        vm.expectEmit(true, true, true, true);
        emit SetTotalSupply(300 ether);
        SharesManagerPublicDeal(payable(address(sharesManager))).mint(_user, 300 ether);

        assert(sharesManager.balanceOf(_user) == 300 ether);

        SharesManagerPublicDeal(payable(address(sharesManager))).setValidatorBalance(440 ether);
        vm.expectEmit(true, true, true, true);
        emit SetTotalSupply(388235294117647058823);
        SharesManagerPublicDeal(payable(address(sharesManager))).mint(_anotherUser, 100 ether);

        assert(sharesManager.balanceOf(_user) == 300 ether);
        assert(sharesManager.balanceOf(_anotherUser) == 88235294117647058823);

        assert(sharesManager.balanceOfUnderlying(_user) == 340 ether);
        assert(sharesManager.balanceOfUnderlying(_anotherUser) == 99999999999999999999); // rounding issues with solidity, diff is negligible
    }

    function testName() public view {
        assert(keccak256("Liquid Staked ETH") == keccak256(bytes(sharesManager.name())));
    }

    function testSymbol() public view {
        assert(keccak256("LsETH") == keccak256(bytes(sharesManager.symbol())));
    }

    function testDecimals() public view {
        assert(18 == sharesManager.decimals());
    }

    function testTotalSupply(uint256 _userSalt, uint128 validatorBalanceSum, uint128 depositSize) public {
        address _user = uf._new(_userSalt);
        vm.deal(_user, depositSize);
        vm.startPrank(_user);
        assert(sharesManager.totalUnderlyingSupply() == 0);
        SharesManagerPublicDeal(payable(address(sharesManager))).setValidatorBalance(validatorBalanceSum);
        (bool sent,) = payable(address(sharesManager)).call{value: depositSize}("");
        assert(sent == true);
        assert(sharesManager.totalUnderlyingSupply() == uint256(validatorBalanceSum) + uint256(depositSize));
        vm.stopPrank();
    }

    function testApprove(uint256 _userOneSalt, uint256 _userTwoSalt, uint256 _allowance) public {
        address _userOne = uf._new(_userOneSalt);
        address _userTwo = uf._new(_userTwoSalt);
        SharesManagerPublicDeal(payable(address(sharesManager))).deal(_userOne, _allowance);
        vm.startPrank(_userOne);
        assert(0 == sharesManager.allowance(_userOne, _userTwo));
        sharesManager.approve(_userTwo, _allowance);
        assert(_allowance == sharesManager.allowance(_userOne, _userTwo));
        vm.stopPrank();
    }

    function testApproveZeroAddress(uint256 _userOneSalt, uint256 _allowance) public {
        address _userOne = uf._new(_userOneSalt);
        SharesManagerPublicDeal(payable(address(sharesManager))).deal(_userOne, _allowance);
        vm.startPrank(_userOne);
        vm.expectRevert(abi.encodeWithSignature("InvalidZeroAddress()"));
        sharesManager.approve(address(0), _allowance);
        vm.stopPrank();
    }

    function testApproveAndTransferPartial(uint256 _userOneSalt, uint256 _userTwoSalt, uint128 _allowance) public {
        address _userOne = uf._new(_userOneSalt);
        address _userTwo = uf._new(_userTwoSalt);
        SharesManagerPublicDeal(payable(address(sharesManager))).deal(_userOne, _allowance);
        SharesManagerPublicDeal(payable(address(sharesManager))).setValidatorBalance(uint256(_allowance));
        vm.startPrank(_userOne);
        uint256 totalAllowance = sharesManager.balanceOf(_userOne);
        assert(0 == sharesManager.allowance(_userOne, _userTwo));
        sharesManager.approve(_userTwo, totalAllowance);
        assert(totalAllowance == sharesManager.allowance(_userOne, _userTwo));
        assert(totalAllowance == sharesManager.balanceOf(_userOne));
        assert(0 == sharesManager.balanceOf(_userTwo));
        uint256 transferValue = totalAllowance / 2;
        vm.stopPrank();
        if (transferValue > 0) {
            vm.startPrank(_userTwo);
            sharesManager.transferFrom(_userOne, _userTwo, transferValue);
            uint256 newBalanceUserOne = (sharesManager.balanceOf(_userOne) * sharesManager.totalUnderlyingSupply())
                / sharesManager.totalSupply();
            uint256 newBalanceUserTwo = (sharesManager.balanceOf(_userTwo) * sharesManager.totalUnderlyingSupply())
                / sharesManager.totalSupply();
            assert(totalAllowance - transferValue == sharesManager.allowance(_userOne, _userTwo));
            assert(newBalanceUserOne == sharesManager.balanceOf(_userOne));
            assert(newBalanceUserTwo == sharesManager.balanceOf(_userTwo));
            assert(newBalanceUserOne + newBalanceUserTwo == totalAllowance);
            vm.stopPrank();
        }
    }

    function testApproveAndTransferTotal(uint256 _userOneSalt, uint256 _userTwoSalt, uint128 _allowance) public {
        address _userOne = uf._new(_userOneSalt);
        address _userTwo = uf._new(_userTwoSalt);
        SharesManagerPublicDeal(payable(address(sharesManager))).deal(_userOne, _allowance);
        SharesManagerPublicDeal(payable(address(sharesManager))).setValidatorBalance(uint256(_allowance));
        vm.startPrank(_userOne);
        uint256 totalAllowance = sharesManager.balanceOf(_userOne);
        assert(0 == sharesManager.allowance(_userOne, _userTwo));
        sharesManager.approve(_userTwo, totalAllowance);
        vm.stopPrank();
        assert(totalAllowance == sharesManager.allowance(_userOne, _userTwo));
        assert(totalAllowance == sharesManager.balanceOf(_userOne));
        assert(0 == sharesManager.balanceOf(_userTwo));
        uint256 transferValue = totalAllowance;
        if (transferValue > 0) {
            vm.startPrank(_userTwo);
            sharesManager.transferFrom(_userOne, _userTwo, transferValue);
            uint256 newBalanceUserOne = 0;
            uint256 newBalanceUserTwo = sharesManager.totalUnderlyingSupply();
            assert(0 == sharesManager.allowance(_userOne, _userTwo));
            assert(newBalanceUserOne == sharesManager.balanceOf(_userOne));
            assert(newBalanceUserTwo == sharesManager.balanceOf(_userTwo));
            assert(newBalanceUserOne + newBalanceUserTwo == totalAllowance);
            vm.stopPrank();
        }
    }

    function testApproveAndTransferZero(uint256 _userOneSalt, uint256 _userTwoSalt, uint128 _allowance) public {
        address _userOne = uf._new(_userOneSalt);
        address _userTwo = uf._new(_userTwoSalt);
        SharesManagerPublicDeal(payable(address(sharesManager))).deal(_userOne, _allowance);
        SharesManagerPublicDeal(payable(address(sharesManager))).setValidatorBalance(uint256(_allowance));
        vm.startPrank(_userOne);
        uint256 totalAllowance = sharesManager.balanceOf(_userOne);
        sharesManager.approve(_userTwo, totalAllowance);
        vm.stopPrank();
        vm.startPrank(_userTwo);
        vm.expectRevert(abi.encodeWithSignature("NullTransfer()"));
        sharesManager.transferFrom(_userOne, _userTwo, 0);
        vm.stopPrank();
    }

    function testApproveAndTransferAboveAllowance(uint256 _userOneSalt, uint256 _userTwoSalt, uint128 _allowance)
        public
    {
        address _userOne = uf._new(_userOneSalt);
        address _userTwo = uf._new(_userTwoSalt);
        SharesManagerPublicDeal(payable(address(sharesManager))).deal(_userOne, _allowance);
        SharesManagerPublicDeal(payable(address(sharesManager))).setValidatorBalance(uint256(_allowance));
        vm.startPrank(_userOne);
        uint256 totalAllowance = sharesManager.balanceOf(_userOne);
        sharesManager.approve(_userTwo, totalAllowance / 2);
        vm.stopPrank();
        if (totalAllowance > 0) {
            vm.startPrank(_userTwo);
            vm.expectRevert(
                abi.encodeWithSignature(
                    "AllowanceTooLow(address,address,uint256,uint256)",
                    _userOne,
                    _userTwo,
                    totalAllowance / 2,
                    totalAllowance
                )
            );
            sharesManager.transferFrom(_userOne, _userTwo, totalAllowance);
            vm.stopPrank();
        }
    }

    function testApproveAndTransferAboveBalance(uint256 _userOneSalt, uint256 _userTwoSalt, uint128 _allowance)
        public
    {
        address _userOne = uf._new(_userOneSalt);
        address _userTwo = uf._new(_userTwoSalt);
        SharesManagerPublicDeal(payable(address(sharesManager))).deal(_userOne, _allowance / 2);
        SharesManagerPublicDeal(payable(address(sharesManager))).setValidatorBalance(_allowance / 2);
        vm.startPrank(_userOne);
        sharesManager.approve(_userTwo, _allowance);
        vm.stopPrank();
        if (_allowance > 0) {
            vm.startPrank(_userTwo);
            vm.expectRevert(abi.encodeWithSignature("BalanceTooLow()"));
            sharesManager.transferFrom(_userOne, _userTwo, _allowance);
            vm.stopPrank();
        }
    }

    function testApproveAndTransferUnauthorized(uint256 _userOneSalt, uint256 _userTwoSalt, uint128 _allowance)
        public
    {
        address _userOne = uf._new(_userOneSalt);
        address _userTwo = uf._new(_userTwoSalt);
        SharesManagerPublicDeal(payable(address(sharesManager))).deal(_userOne, _allowance);
        SharesManagerPublicDeal(payable(address(sharesManager))).setValidatorBalance(uint256(_allowance));
        if (_allowance > 0) {
            vm.startPrank(_userTwo);
            vm.expectRevert(
                abi.encodeWithSignature(
                    "AllowanceTooLow(address,address,uint256,uint256)", _userOne, _userTwo, 0, _allowance
                )
            );
            sharesManager.transferFrom(_userOne, _userTwo, _allowance);
            vm.stopPrank();
        }
    }

    function testTransferPartial(uint256 _userOneSalt, uint256 _userTwoSalt, uint128 _allowance) public {
        address _userOne = uf._new(_userOneSalt);
        address _userTwo = uf._new(_userTwoSalt);
        SharesManagerPublicDeal(payable(address(sharesManager))).deal(_userOne, _allowance);
        SharesManagerPublicDeal(payable(address(sharesManager))).setValidatorBalance(uint256(_allowance));
        vm.startPrank(_userOne);
        uint256 totalAllowance = sharesManager.balanceOf(_userOne);
        assert(0 == sharesManager.balanceOf(_userTwo));
        uint256 transferValue = totalAllowance / 2;
        if (transferValue > 0) {
            sharesManager.transfer(_userTwo, transferValue);
            uint256 newBalanceUserOne = (sharesManager.balanceOf(_userOne) * sharesManager.totalUnderlyingSupply())
                / sharesManager.totalSupply();
            uint256 newBalanceUserTwo = (sharesManager.balanceOf(_userTwo) * sharesManager.totalUnderlyingSupply())
                / sharesManager.totalSupply();
            assert(newBalanceUserOne == sharesManager.balanceOf(_userOne));
            assert(newBalanceUserTwo == sharesManager.balanceOf(_userTwo));
            assert(newBalanceUserOne + newBalanceUserTwo == totalAllowance);
        }
        vm.stopPrank();
    }

    function testTransferZeroAddress(uint256 _userOneSalt, uint256 _userTwoSalt, uint128 _allowance) public {
        address _userOne = uf._new(_userOneSalt);
        address _userTwo = uf._new(_userTwoSalt);
        SharesManagerPublicDeal(payable(address(sharesManager))).deal(_userOne, _allowance);
        SharesManagerPublicDeal(payable(address(sharesManager))).setValidatorBalance(uint256(_allowance));
        vm.startPrank(_userOne);
        uint256 totalAllowance = sharesManager.balanceOf(_userOne);
        assert(0 == sharesManager.balanceOf(_userTwo));
        uint256 transferValue = totalAllowance / 2;
        if (transferValue > 0) {
            vm.expectRevert(abi.encodeWithSignature("UnauthorizedTransfer(address,address)", _userOne, address(0)));
            sharesManager.transfer(address(0), transferValue);
        }
        vm.stopPrank();
    }

    function testTransferTotal(uint256 _userOneSalt, uint256 _userTwoSalt, uint128 _allowance) public {
        address _userOne = uf._new(_userOneSalt);
        address _userTwo = uf._new(_userTwoSalt);
        SharesManagerPublicDeal(payable(address(sharesManager))).deal(_userOne, _allowance);
        SharesManagerPublicDeal(payable(address(sharesManager))).setValidatorBalance(uint256(_allowance));
        vm.startPrank(_userOne);
        uint256 totalAllowance = sharesManager.balanceOf(_userOne);
        assert(0 == sharesManager.balanceOf(_userTwo));
        uint256 transferValue = totalAllowance;
        if (transferValue > 0) {
            sharesManager.transfer(_userTwo, transferValue);
            uint256 newBalanceUserOne = 0;
            uint256 newBalanceUserTwo = _allowance;
            assert(newBalanceUserOne == sharesManager.balanceOf(_userOne));
            assert(newBalanceUserTwo == sharesManager.balanceOf(_userTwo));
            assert(newBalanceUserOne + newBalanceUserTwo == totalAllowance);
        }
        vm.stopPrank();
    }

    function testApproveAndTransferMsgSender(uint256 _userOneSalt, uint256 _userTwoSalt, uint128 _allowance) public {
        address _userOne = uf._new(_userOneSalt);
        address _userTwo = uf._new(_userTwoSalt);
        SharesManagerPublicDeal(payable(address(sharesManager))).deal(_userOne, _allowance);
        if (_allowance > 0) {
            vm.startPrank(_userOne);
            vm.expectRevert(
                abi.encodeWithSignature(
                    "AllowanceTooLow(address,address,uint256,uint256)", _userOne, _userOne, 0, _allowance
                )
            );
            sharesManager.transferFrom(_userOne, _userTwo, _allowance);
            vm.stopPrank();
        }
    }

    function testApproveAndTransferZeroAddress(uint256 _userOneSalt, uint256 _userTwoSalt, uint128 _allowance) public {
        address _userOne = uf._new(_userOneSalt);
        address _userTwo = uf._new(_userTwoSalt);
        SharesManagerPublicDeal(payable(address(sharesManager))).deal(_userOne, _allowance);
        if (_allowance > 0) {
            vm.prank(_userOne);
            sharesManager.approve(_userTwo, _allowance);
            vm.prank(_userTwo);
            vm.expectRevert(abi.encodeWithSignature("UnauthorizedTransfer(address,address)", _userOne, address(0)));
            sharesManager.transferFrom(_userOne, address(0), _allowance);
            vm.stopPrank();
        }
    }

    function testIncreaseAllowanceAndTransferFrom(uint256 _userOneSalt, uint256 _userTwoSalt, uint128 _allowance)
        public
    {
        address _userOne = uf._new(_userOneSalt);
        address _userTwo = uf._new(_userTwoSalt);
        SharesManagerPublicDeal(payable(address(sharesManager))).deal(_userOne, _allowance);
        vm.prank(_userOne);
        sharesManager.increaseAllowance(_userTwo, _allowance);
        if (_allowance > 0) {
            vm.startPrank(_userTwo);
            sharesManager.transferFrom(_userOne, _userTwo, _allowance);
            vm.stopPrank();
            assert(sharesManager.balanceOf(_userTwo) == _allowance);
        }
    }

    function testIncreaseDecreaseAllowanceAndTransferFrom(
        uint256 _userOneSalt,
        uint256 _userTwoSalt,
        uint128 _allowance
    ) public {
        address _userOne = uf._new(_userOneSalt);
        address _userTwo = uf._new(_userTwoSalt);
        SharesManagerPublicDeal(payable(address(sharesManager))).deal(_userOne, _allowance);
        vm.prank(_userOne);
        sharesManager.increaseAllowance(_userTwo, uint256(_allowance) * 2);
        vm.prank(_userOne);
        sharesManager.decreaseAllowance(_userTwo, _allowance);
        if (_allowance > 0) {
            vm.startPrank(_userTwo);
            sharesManager.transferFrom(_userOne, _userTwo, _allowance);
            vm.stopPrank();
            assert(sharesManager.balanceOf(_userTwo) == _allowance);
        }
    }

    function testApproveAndTransferUnauthorizedSender(uint256 _userOneSalt, uint256 _userTwoSalt, uint128 _allowance)
        public
    {
        address _userOne = uf._new(_userOneSalt);
        address _userTwo = uf._new(_userTwoSalt);
        SharesManagerPublicDeal(payable(address(sharesManager))).deal(_userOne, _allowance);
        SharesManagerPublicDeal(payable(address(sharesManager))).setValidatorBalance(uint256(_allowance));
        SharesManagerPublicDeal(payable(address(sharesManager))).setDenied(_userOne);
        vm.startPrank(_userOne);
        uint256 totalAllowance = sharesManager.balanceOf(_userOne);
        assert(0 == sharesManager.allowance(_userOne, _userTwo));
        sharesManager.approve(_userTwo, totalAllowance);
        vm.stopPrank();
        assert(totalAllowance == sharesManager.allowance(_userOne, _userTwo));
        assert(totalAllowance == sharesManager.balanceOf(_userOne));
        assert(0 == sharesManager.balanceOf(_userTwo));
        uint256 transferValue = totalAllowance;
        if (transferValue > 0) {
            vm.startPrank(_userTwo);
            vm.expectRevert(abi.encodeWithSignature("Denied(address)", _userOne));
            sharesManager.transferFrom(_userOne, _userTwo, transferValue);
            vm.stopPrank();
        }
    }

    function testApproveAndTransferUnauthorizedReceiver(uint256 _userOneSalt, uint256 _userTwoSalt, uint128 _allowance)
        public
    {
        address _userOne = uf._new(_userOneSalt);
        address _userTwo = uf._new(_userTwoSalt);
        SharesManagerPublicDeal(payable(address(sharesManager))).deal(_userOne, _allowance);
        SharesManagerPublicDeal(payable(address(sharesManager))).setValidatorBalance(uint256(_allowance));
        SharesManagerPublicDeal(payable(address(sharesManager))).setDenied(_userTwo);
        vm.startPrank(_userOne);
        uint256 totalAllowance = sharesManager.balanceOf(_userOne);
        assert(0 == sharesManager.allowance(_userOne, _userTwo));
        sharesManager.approve(_userTwo, totalAllowance);
        vm.stopPrank();
        assert(totalAllowance == sharesManager.allowance(_userOne, _userTwo));
        assert(totalAllowance == sharesManager.balanceOf(_userOne));
        assert(0 == sharesManager.balanceOf(_userTwo));
        uint256 transferValue = totalAllowance;
        if (transferValue > 0) {
            vm.startPrank(_userTwo);
            vm.expectRevert(abi.encodeWithSignature("Denied(address)", _userTwo));
            sharesManager.transferFrom(_userOne, _userTwo, transferValue);
            vm.stopPrank();
        }
    }

    function testTransferUnauthorizedSender(uint256 _userOneSalt, uint256 _userTwoSalt, uint128 _allowance) public {
        address _userOne = uf._new(_userOneSalt);
        address _userTwo = uf._new(_userTwoSalt);
        SharesManagerPublicDeal(payable(address(sharesManager))).deal(_userOne, _allowance);
        SharesManagerPublicDeal(payable(address(sharesManager))).setValidatorBalance(uint256(_allowance));
        SharesManagerPublicDeal(payable(address(sharesManager))).setDenied(_userOne);

        vm.startPrank(_userOne);
        uint256 totalAllowance = sharesManager.balanceOf(_userOne);
        assert(0 == sharesManager.balanceOf(_userTwo));
        uint256 transferValue = totalAllowance;
        if (transferValue > 0) {
            vm.expectRevert(abi.encodeWithSignature("Denied(address)", _userOne));
            sharesManager.transfer(_userTwo, transferValue);
        }
        vm.stopPrank();
    }

    function testTransferUnauthorizedReceiver(uint256 _userOneSalt, uint256 _userTwoSalt, uint128 _allowance) public {
        address _userOne = uf._new(_userOneSalt);
        address _userTwo = uf._new(_userTwoSalt);
        SharesManagerPublicDeal(payable(address(sharesManager))).deal(_userOne, _allowance);
        SharesManagerPublicDeal(payable(address(sharesManager))).setValidatorBalance(uint256(_allowance));
        SharesManagerPublicDeal(payable(address(sharesManager))).setDenied(_userTwo);

        vm.startPrank(_userOne);
        uint256 totalAllowance = sharesManager.balanceOf(_userOne);
        assert(0 == sharesManager.balanceOf(_userTwo));
        uint256 transferValue = totalAllowance;
        if (transferValue > 0) {
            vm.expectRevert(abi.encodeWithSignature("Denied(address)", _userTwo));
            sharesManager.transfer(_userTwo, transferValue);
        }
        vm.stopPrank();
    }

    function testTransferTransferZero(uint256 _userOneSalt, uint256 _userTwoSalt, uint128 _allowance) public {
        address _userOne = uf._new(_userOneSalt);
        address _userTwo = uf._new(_userTwoSalt);
        SharesManagerPublicDeal(payable(address(sharesManager))).deal(_userOne, _allowance);
        SharesManagerPublicDeal(payable(address(sharesManager))).setValidatorBalance(uint256(_allowance));
        vm.startPrank(_userOne);
        assert(0 == sharesManager.balanceOf(_userTwo));
        vm.expectRevert(abi.encodeWithSignature("NullTransfer()"));
        sharesManager.transfer(_userTwo, 0);
        vm.stopPrank();
    }

    function testTransferTransferBalanceTooLow(uint256 _userOneSalt, uint256 _userTwoSalt) public {
        address _userOne = uf._new(_userOneSalt);
        address _userTwo = uf._new(_userTwoSalt);
        vm.startPrank(_userOne);
        assert(0 == sharesManager.balanceOf(_userTwo));
        vm.expectRevert(abi.encodeWithSignature("BalanceTooLow()"));
        sharesManager.transfer(_userTwo, 1);
        vm.stopPrank();
    }
}
