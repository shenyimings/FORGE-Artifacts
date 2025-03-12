// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.23;

import "../lib/forge-std/src/Test.sol";
import "../contracts/factories/CrowdinvestingCloneFactory.sol";
import "../contracts/factories/TokenProxyFactory.sol";
import "../contracts/factories/FeeSettingsCloneFactory.sol";
import "./resources/ERC2771Helper.sol";
import "./resources/CloneCreators.sol";

contract tokenTest is Test {
    using ECDSA for bytes32;

    AllowList allowList;
    FeeSettings feeSettings;
    TokenProxyFactory tokenFactory;
    Crowdinvesting fundraisingImplementation;
    CrowdinvestingCloneFactory fundraisingFactory;
    address public constant trustedForwarder = 0x9109709EcFA91A80626FF3989D68f67F5B1dD129;
    address public constant admin = 0x0109709eCFa91a80626FF3989D68f67f5b1dD120;
    address public constant requirer = 0x1109709ecFA91a80626ff3989D68f67F5B1Dd121;
    address public constant mintAllower = 0x2109709EcFa91a80626Ff3989d68F67F5B1Dd122;
    address public constant minter = 0x3109709ECfA91A80626fF3989D68f67F5B1Dd123;
    address public constant burner = 0x4109709eCFa91A80626ff3989d68F67f5b1DD124;
    address public constant transfererAdmin = 0x5109709EcFA91a80626ff3989d68f67F5B1dD125;
    address public constant transferer = 0x6109709EcFA91A80626FF3989d68f67F5b1dd126;
    address public constant pauser = 0x7109709eCfa91A80626Ff3989D68f67f5b1dD127;
    address public constant feeSettingsAndAllowListOwner = 0x8109709ecfa91a80626fF3989d68f67F5B1dD128;

    uint256 requirements = 0;

    // these are defined globally to make some tests work in spite of compiler limitations
    bytes32 public constant exampleRawSalt = 0x00000000;
    address public constant exampleTrustedForwarder = address(52);
    address public constant exampleOwner = address(53);
    address public constant exampleCurrencyReceiver = address(54);
    uint256 public constant exampleMinAmountPerBuyer = 1;
    uint256 public constant exampleMaxAmountPerBuyer = type(uint256).max;
    uint256 public constant exampleTokenPrice = 2;
    uint256 public constant exampleMinTokenPrice = 1;
    uint256 public constant exampleMaxTokenPrice = type(uint256).max;
    uint256 public constant exampleMaxAmountOfTokenToBeSold = 82398479821374;
    IERC20 public constant exampleCurrency = IERC20(address(1));
    Token public constant exampleToken = Token(address(2));
    uint256 public constant exampleLastBuyDate = 0;
    address public constant examplePriceOracle = address(3);

    event RequirementsChanged(uint256 newRequirements);

    function setUp() public {
        vm.startPrank(feeSettingsAndAllowListOwner);
        allowList = createAllowList(trustedForwarder, feeSettingsAndAllowListOwner);
        Fees memory fees = Fees(1, 100, 1, 100, 1, 100, 0);
        FeeSettings feeSettingsLogicContract = new FeeSettings(trustedForwarder);
        FeeSettingsCloneFactory feeSettingsCloneFactory = new FeeSettingsCloneFactory(
            address(feeSettingsLogicContract)
        );
        feeSettings = FeeSettings(
            feeSettingsCloneFactory.createFeeSettingsClone(
                0,
                trustedForwarder,
                feeSettingsAndAllowListOwner,
                fees,
                feeSettingsAndAllowListOwner,
                feeSettingsAndAllowListOwner,
                feeSettingsAndAllowListOwner
            )
        );
        vm.stopPrank();

        Token tokenImplementation = new Token(trustedForwarder);
        tokenFactory = new TokenProxyFactory(address(tokenImplementation));

        fundraisingImplementation = new Crowdinvesting(trustedForwarder);
        fundraisingFactory = new CrowdinvestingCloneFactory(address(fundraisingImplementation));
    }

    function testAddressPrediction1(
        uint256 _maxAmountPerBuyer,
        uint256 _tokenPrice,
        uint256 _tokenPriceMin,
        uint256 _tokenPriceMax,
        uint256 _maxAmountOfTokenToBeSold,
        IERC20 _currency,
        Token _token,
        uint256 _lastBuyDate,
        address _priceOracle
    ) public {
        vm.assume(address(_currency) != address(0));
        vm.assume(address(_token) != address(0));
        vm.assume(exampleMinAmountPerBuyer > 0);
        vm.assume(_maxAmountPerBuyer >= exampleMinAmountPerBuyer);
        vm.assume(_tokenPrice > 0);
        vm.assume(_tokenPriceMin <= _tokenPrice);
        vm.assume(_tokenPriceMax >= _tokenPrice);
        vm.assume(_maxAmountOfTokenToBeSold > _maxAmountPerBuyer);

        // create new clone factory so we can use the local forwarder
        fundraisingImplementation = new Crowdinvesting(exampleTrustedForwarder);
        fundraisingFactory = new CrowdinvestingCloneFactory(address(fundraisingImplementation));

        CrowdinvestingInitializerArguments memory arguments = CrowdinvestingInitializerArguments(
            exampleOwner,
            exampleCurrencyReceiver,
            exampleMinAmountPerBuyer,
            _maxAmountPerBuyer,
            _tokenPrice,
            _tokenPriceMin,
            _tokenPriceMax,
            _maxAmountOfTokenToBeSold,
            _currency,
            _token,
            _lastBuyDate,
            _priceOracle
        );

        address expected1 = fundraisingFactory.predictCloneAddress(
            keccak256(abi.encode(exampleRawSalt, exampleTrustedForwarder, arguments))
        );

        address expected2 = fundraisingFactory.predictCloneAddress(exampleRawSalt, exampleTrustedForwarder, arguments);

        assertEq(expected1, expected2, "address prediction with salt and params not equal");

        address actual = fundraisingFactory.createCrowdinvestingClone(
            exampleRawSalt,
            exampleTrustedForwarder,
            arguments
        );
        assertEq(expected1, actual, "address prediction failed");
    }

    function testAddressPrediction2(
        bytes32 _rawSalt,
        address _trustedForwarder,
        address _owner,
        address _currencyReceiver,
        uint256 _minAmountPerBuyer
    ) public {
        vm.assume(_trustedForwarder != address(0));
        vm.assume(_owner != address(0));
        vm.assume(_currencyReceiver != address(0));
        vm.assume(_minAmountPerBuyer > 0);

        // create new clone factory so we can use the local forwarder
        fundraisingImplementation = new Crowdinvesting(_trustedForwarder);
        fundraisingFactory = new CrowdinvestingCloneFactory(address(fundraisingImplementation));

        CrowdinvestingInitializerArguments memory arguments = CrowdinvestingInitializerArguments(
            _owner,
            _currencyReceiver,
            _minAmountPerBuyer,
            exampleMaxAmountPerBuyer,
            exampleTokenPrice,
            exampleMinTokenPrice,
            exampleMaxTokenPrice,
            exampleMaxAmountOfTokenToBeSold,
            exampleCurrency,
            exampleToken,
            exampleLastBuyDate,
            examplePriceOracle
        );

        bytes32 salt = keccak256(abi.encode(_rawSalt, _trustedForwarder, arguments));

        address expected1 = fundraisingFactory.predictCloneAddress(salt);
        address expected2 = fundraisingFactory.predictCloneAddress(_rawSalt, _trustedForwarder, arguments);

        assertEq(expected1, expected2, "address prediction with salt and params not equal");

        address actual = fundraisingFactory.createCrowdinvestingClone(_rawSalt, _trustedForwarder, arguments);
        assertEq(expected1, actual, "address prediction failed");
    }

    function testChangingOneValueInStructChangesAddress(
        bytes32 _rawSalt,
        address _trustedForwarder,
        address _owner,
        address _currencyReceiver,
        uint256 _minAmountPerBuyer
    ) public {
        vm.assume(_trustedForwarder != address(0));
        vm.assume(_owner != address(0));
        vm.assume(_currencyReceiver != address(0));
        vm.assume(_minAmountPerBuyer > 0);

        // create new clone factory so we can use the local forwarder
        fundraisingImplementation = new Crowdinvesting(_trustedForwarder);
        fundraisingFactory = new CrowdinvestingCloneFactory(address(fundraisingImplementation));

        CrowdinvestingInitializerArguments memory arguments = CrowdinvestingInitializerArguments(
            _owner,
            _currencyReceiver,
            _minAmountPerBuyer,
            exampleMaxAmountPerBuyer,
            exampleTokenPrice,
            exampleMinTokenPrice,
            exampleMaxTokenPrice,
            exampleMaxAmountOfTokenToBeSold,
            exampleCurrency,
            exampleToken,
            exampleLastBuyDate,
            examplePriceOracle
        );

        address expected1 = fundraisingFactory.predictCloneAddress(_rawSalt, _trustedForwarder, arguments);

        arguments.maxAmountPerBuyer = exampleMaxAmountPerBuyer - 1;

        address expected2 = fundraisingFactory.predictCloneAddress(_rawSalt, _trustedForwarder, arguments);

        assertFalse(expected1 == expected2, "these addresses can not be equal");
    }

    function testSecondDeploymentFails(
        bytes32 _rawSalt,
        address _owner,
        address _currencyReceiver,
        uint256 _minAmountPerBuyer,
        uint256 _maxAmountPerBuyer,
        uint256 _priceBase,
        uint256 _tokenPriceMin,
        uint256 _tokenPriceMax,
        uint256 _maxAmountOfTokenToBeSold,
        IERC20 _currency,
        Token _token
    ) public {
        vm.assume(_owner != address(0));
        vm.assume(address(_currency) != address(0));
        vm.assume(address(_token) != address(0));
        vm.assume(_currencyReceiver != address(0));
        vm.assume(_minAmountPerBuyer > 0);
        vm.assume(_maxAmountPerBuyer >= _minAmountPerBuyer);
        vm.assume(_priceBase > 0);
        vm.assume(_tokenPriceMin <= _priceBase);
        vm.assume(_tokenPriceMax >= _priceBase);
        vm.assume(_maxAmountOfTokenToBeSold > _maxAmountPerBuyer);

        CrowdinvestingInitializerArguments memory arguments = CrowdinvestingInitializerArguments(
            _owner,
            _currencyReceiver,
            _minAmountPerBuyer,
            _maxAmountPerBuyer,
            _priceBase,
            _tokenPriceMin,
            _tokenPriceMax,
            _maxAmountOfTokenToBeSold,
            _currency,
            _token,
            exampleLastBuyDate,
            examplePriceOracle
        );

        // deploy once
        fundraisingFactory.createCrowdinvestingClone(_rawSalt, trustedForwarder, arguments);

        // deploy again
        vm.expectRevert("ERC1167: create2 failed");
        fundraisingFactory.createCrowdinvestingClone(_rawSalt, trustedForwarder, arguments);
    }

    function testInitialization1(
        bytes32 _rawSalt,
        address _trustedForwarder,
        address _owner,
        address _currencyReceiver,
        uint256 _minAmountPerBuyer,
        uint256 _maxAmountPerBuyer
    ) public {
        vm.assume(_trustedForwarder != address(0));
        vm.assume(_owner != address(0));
        vm.assume(_currencyReceiver != address(0));
        vm.assume(_minAmountPerBuyer > 0);
        vm.assume(_maxAmountPerBuyer >= _minAmountPerBuyer);

        // create new clone factory so we can use the local forwarder
        fundraisingImplementation = new Crowdinvesting(_trustedForwarder);
        fundraisingFactory = new CrowdinvestingCloneFactory(address(fundraisingImplementation));

        CrowdinvestingInitializerArguments memory arguments = CrowdinvestingInitializerArguments(
            _owner,
            _currencyReceiver,
            _minAmountPerBuyer,
            _maxAmountPerBuyer,
            exampleTokenPrice,
            exampleMinTokenPrice,
            exampleMaxTokenPrice,
            exampleMaxAmountOfTokenToBeSold,
            exampleCurrency,
            exampleToken,
            exampleLastBuyDate,
            examplePriceOracle
        );

        Crowdinvesting crowdinvesting = Crowdinvesting(
            fundraisingFactory.createCrowdinvestingClone(_rawSalt, _trustedForwarder, arguments)
        );

        assertTrue(crowdinvesting.isTrustedForwarder(_trustedForwarder), "trustedForwarder not set");
        assertEq(crowdinvesting.owner(), _owner, "owner not set");
        assertEq(crowdinvesting.currencyReceiver(), _currencyReceiver, "currencyReceiver not set");
        assertEq(crowdinvesting.minAmountPerBuyer(), _minAmountPerBuyer, "minAmountPerBuyer not set");
        assertEq(crowdinvesting.maxAmountPerBuyer(), _maxAmountPerBuyer, "maxAmountPerBuyer not set");
    }

    function testInitialization2(
        uint256 _maxAmountPerBuyer,
        uint256 _priceBase,
        uint256 _priceMin,
        uint256 _priceMax,
        uint256 _maxAmountOfTokenToBeSold,
        IERC20 _currency,
        Token _token,
        uint256 _lastBuyDate,
        address _priceOracle
    ) public {
        vm.assume(address(_currency) != address(0));
        vm.assume(address(_token) != address(0));
        vm.assume(_priceBase > 0);
        vm.assume(_priceMin <= _priceBase);
        vm.assume(_priceMax >= _priceBase);
        vm.assume(_maxAmountOfTokenToBeSold > _maxAmountPerBuyer);
        vm.assume(_maxAmountPerBuyer > 0);

        // create new clone factory so we can use the local forwarder
        fundraisingImplementation = new Crowdinvesting(exampleTrustedForwarder);
        fundraisingFactory = new CrowdinvestingCloneFactory(address(fundraisingImplementation));

        CrowdinvestingInitializerArguments memory arguments = CrowdinvestingInitializerArguments(
            exampleOwner,
            exampleCurrencyReceiver,
            exampleMinAmountPerBuyer,
            _maxAmountPerBuyer,
            _priceBase,
            _priceMin,
            _priceMax,
            _maxAmountOfTokenToBeSold,
            _currency,
            _token,
            _lastBuyDate,
            _priceOracle
        );

        Crowdinvesting crowdinvesting = Crowdinvesting(
            fundraisingFactory.createCrowdinvestingClone(exampleRawSalt, exampleTrustedForwarder, arguments)
        );

        assertEq(crowdinvesting.maxAmountPerBuyer(), _maxAmountPerBuyer, "maxAmountPerBuyer not set");
        assertEq(crowdinvesting.priceBase(), _priceBase, "priceBase not set");
        assertEq(crowdinvesting.priceMin(), _priceMin, "priceMin not set");
        assertEq(crowdinvesting.priceMax(), _priceMax, "priceMax not set");
        assertEq(
            crowdinvesting.maxAmountOfTokenToBeSold(),
            _maxAmountOfTokenToBeSold,
            "maxAmountOfTokenToBeSold not set"
        );
        assertEq(address(crowdinvesting.currency()), address(_currency), "currency not set");
        assertEq(address(crowdinvesting.token()), address(_token), "token not set");
        assertEq(crowdinvesting.lastBuyDate(), _lastBuyDate, "lastBuyDate not set");
        assertEq(address(crowdinvesting.priceOracle()), _priceOracle, "priceOracle not set");
    }

    /*
        pausing and unpausing
    */
    function testPausing(address _admin, address rando) public {
        vm.assume(_admin != address(0));
        vm.assume(rando != address(0));
        vm.assume(rando != _admin);

        CrowdinvestingInitializerArguments memory arguments = CrowdinvestingInitializerArguments(
            _admin,
            _admin,
            exampleMinAmountPerBuyer,
            exampleMaxAmountPerBuyer,
            exampleTokenPrice,
            exampleMinTokenPrice,
            exampleMaxTokenPrice,
            exampleMaxAmountOfTokenToBeSold,
            exampleCurrency,
            exampleToken,
            exampleLastBuyDate,
            examplePriceOracle
        );

        Crowdinvesting crowdinvesting = Crowdinvesting(
            fundraisingFactory.createCrowdinvestingClone(0, trustedForwarder, arguments)
        );

        vm.prank(rando);
        vm.expectRevert("Ownable: caller is not the owner");
        crowdinvesting.pause();

        assertFalse(crowdinvesting.paused());
        vm.prank(_admin);
        crowdinvesting.pause();
        assertTrue(crowdinvesting.paused());

        vm.prank(rando);
        vm.expectRevert("Ownable: caller is not the owner");
        crowdinvesting.unpause();

        // can't buy when paused
        vm.prank(rando);
        vm.expectRevert("Pausable: paused");
        crowdinvesting.buy(1, address(this));

        vm.warp(block.timestamp + 1 days + 1);
        vm.prank(_admin);
        crowdinvesting.unpause();
    }
}
