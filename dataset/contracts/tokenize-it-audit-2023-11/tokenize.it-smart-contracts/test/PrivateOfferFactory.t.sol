// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.23;

import "../lib/forge-std/src/Test.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "../contracts/factories/TokenProxyFactory.sol";
import "../contracts/PrivateOffer.sol";
import "../contracts/factories/PrivateOfferFactory.sol";
import "./resources/CloneCreators.sol";
import "./resources/ERC20MintableByAnyone.sol";

contract PrivateOfferFactoryTest is Test {
    event Deploy(address indexed privateOffer);

    PrivateOfferFactory factory;

    AllowList list;
    FeeSettings feeSettings;

    Token token;
    ERC20MintableByAnyone currency;

    uint256 MAX_INT = type(uint256).max;

    address public constant admin = 0x0109709eCFa91a80626FF3989D68f67f5b1dD120;
    address public constant buyer = 0x1109709ecFA91a80626ff3989D68f67F5B1Dd121;
    address public constant mintAllower = 0x2109709EcFa91a80626Ff3989d68F67F5B1Dd122;
    address public constant minter = 0x3109709ECfA91A80626fF3989D68f67F5B1Dd123;
    address public constant owner = 0x6109709EcFA91A80626FF3989d68f67F5b1dd126;
    address public constant currencyReceiver = 0x7109709eCfa91A80626Ff3989D68f67f5b1dD127;
    address public constant paymentTokenProvider = 0x8109709ecfa91a80626fF3989d68f67F5B1dD128;
    address public constant trustedForwarder = 0x9109709EcFA91A80626FF3989D68f67F5B1dD129;

    uint256 public constant price = 10000000;

    uint256 public constant tokenAmount = 3e18;
    uint256 public constant currencyAmount = (tokenAmount * price) / 1e18;
    uint256 public constant expiration = 200 days;
    bytes32 public constant salt = bytes32("234");

    function setUp() public {
        Vesting vestingImplementation = new Vesting(trustedForwarder);
        VestingCloneFactory vestingCloneFactory = new VestingCloneFactory(address(vestingImplementation));
        factory = new PrivateOfferFactory(vestingCloneFactory);
        list = createAllowList(trustedForwarder, owner);
        Fees memory fees = Fees(0, 100, 0, 100, 0, 100, 0);
        feeSettings = createFeeSettings(trustedForwarder, address(this), fees, admin, admin, admin);

        Token implementation = new Token(trustedForwarder);
        TokenProxyFactory tokenCloneFactory = new TokenProxyFactory(address(implementation));
        token = Token(
            tokenCloneFactory.createTokenProxy(0, trustedForwarder, feeSettings, admin, list, 0x0, "token", "TOK")
        );
        currency = new ERC20MintableByAnyone("currency", "CUR");
    }

    function testDeployContract(bytes32 _salt) public {
        //bytes memory creationCode = type(PrivateOffer).creationCode;
        uint256 _amount = 20000000000000;
        uint256 _expiration = block.timestamp + 1000;

        PrivateOfferArguments memory arguments = PrivateOfferArguments(
            buyer,
            buyer,
            currencyReceiver,
            _amount,
            price,
            _expiration,
            IERC20(address(currency)),
            token
        );
        address expectedAddress = factory.predictPrivateOfferAddress(_salt, arguments);

        // make sure no contract lives here yet
        uint256 len;
        assembly {
            len := extcodesize(expectedAddress)
        }
        assert(len == 0);

        vm.prank(admin);
        token.increaseMintingAllowance(expectedAddress, _amount);

        currency.mint(buyer, _amount * price);
        vm.prank(buyer);
        currency.approve(expectedAddress, _amount * price);

        vm.expectEmit(true, true, true, true, address(factory));
        emit Deploy(expectedAddress);
        address actualAddress = factory.deployPrivateOffer(_salt, arguments);

        assertTrue(actualAddress == expectedAddress, "Wrong address returned");

        // make sure contract lives here now
        assembly {
            len := extcodesize(expectedAddress)
        }
        assertTrue(len != 0, "Contract not deployed or to wrong address");
    }

    function testDeployWithTimeLock(
        uint64 _vestingStart,
        uint64 _vestingCliff,
        uint64 _vestingDuration,
        address tokenReceiver,
        address companyAdmin
    ) public {
        vm.assume(_vestingCliff <= _vestingDuration);
        vm.assume(_vestingStart < type(uint64).max / 2);
        vm.assume(_vestingDuration < type(uint64).max / 2);
        vm.assume(_vestingDuration > 0);
        vm.assume(tokenReceiver != address(0));
        vm.assume(tokenReceiver != companyAdmin);
        vm.assume(tokenReceiver != trustedForwarder);
        vm.assume(companyAdmin != trustedForwarder);

        // mint currency to buyer
        currency.mint(buyer, currencyAmount);

        PrivateOfferArguments memory arguments = PrivateOfferArguments(
            buyer,
            tokenReceiver,
            currencyReceiver,
            tokenAmount,
            price,
            expiration,
            IERC20(address(currency)),
            token
        );

        // predict addresses for vesting contract and private offer contract
        (address expectedPrivateOffer, address expectedVesting) = factory.predictPrivateOfferAndTimeLockAddress(
            salt,
            arguments,
            _vestingStart,
            _vestingCliff,
            _vestingDuration,
            companyAdmin,
            trustedForwarder
        );

        // make sure no contract lives here yet
        assertFalse(Address.isContract(expectedPrivateOffer), "Private Offer address already contains contract");
        assertFalse(Address.isContract(expectedVesting), "Vesting address already contains contract");

        // give allowances to private offer contract
        vm.prank(buyer);
        currency.approve(expectedPrivateOffer, currencyAmount);
        vm.prank(admin);
        token.increaseMintingAllowance(expectedPrivateOffer, tokenAmount);

        // check state before deployment
        assertEq(currency.balanceOf(buyer), currencyAmount, "Buyer has wrong currency balance before deployment");
        assertEq(token.balanceOf(buyer), 0, "Buyer has wrong token balance before deployment");
        assertEq(
            currency.balanceOf(currencyReceiver),
            0,
            "Currency receiver has wrong currency balance before deployment"
        );

        // deploy contracts
        assertEq(
            factory.deployPrivateOfferWithTimeLock(
                salt,
                arguments,
                _vestingStart,
                _vestingCliff,
                _vestingDuration,
                companyAdmin,
                trustedForwarder
            ),
            expectedVesting
        );

        // make sure contracts live here now
        assertTrue(Address.isContract(expectedPrivateOffer), "Private Offer address does not contain contract");
        assertTrue(Address.isContract(expectedVesting), "Vesting address does not contain contract");

        // make sure vesting contract is owned by correct address
        Vesting vestingContract = Vesting(expectedVesting);
        if (companyAdmin == address(0)) {
            assertTrue(vestingContract.owner() == address(0), "Vesting contract has owner");
        } else {
            assertTrue(vestingContract.owner() == companyAdmin, "Vesting contract not owned by company admin");
        }

        // check balances again
        assertEq(currency.balanceOf(buyer), 0, "Buyer has wrong currency balance after deployment");
        assertEq(token.balanceOf(buyer), 0, "Buyer has wrong token balance after deployment");
        assertEq(currency.balanceOf(currencyReceiver), currencyAmount, "Currency receiver has wrong currency balance");
        assertEq(token.balanceOf(tokenReceiver), 0, "Token receiver has wrong token balance");
        assertEq(token.balanceOf(expectedVesting), tokenAmount, "Token receiver has wrong token balance");

        // check vesting plan details
        assertEq(vestingContract.token(), address(token), "Vesting contract has wrong token");
        assertEq(vestingContract.beneficiary(1), tokenReceiver, "Vesting contract has wrong beneficiary");
        assertEq(vestingContract.start(1), _vestingStart, "Vesting contract has wrong vesting start");
        assertEq(vestingContract.cliff(1), _vestingCliff, "Vesting contract has wrong vesting cliff");
        assertEq(vestingContract.duration(1), _vestingDuration, "Vesting contract has wrong vesting duration");
        assertEq(vestingContract.allocation(1), tokenAmount, "Vesting contract has wrong vesting amount");

        // try to release tokens
        vm.startPrank(tokenReceiver);
        vestingContract.release(1);
        if (block.timestamp < uint64(_vestingStart + _vestingCliff)) {
            assertEq(token.balanceOf(tokenReceiver), 0, "Token receiver has wrong token balance after first release");
        }

        vm.warp(uint256(_vestingStart + _vestingDuration));
        vestingContract.release(1);
        assertEq(
            token.balanceOf(tokenReceiver),
            tokenAmount,
            "Token receiver has wrong token balance after second release"
        );
    }
}
