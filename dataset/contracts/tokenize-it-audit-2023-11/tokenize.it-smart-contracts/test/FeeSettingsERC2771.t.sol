// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.23;

import "../lib/forge-std/src/Test.sol";
import "../contracts/factories/FeeSettingsCloneFactory.sol";
import "../contracts/FeeSettings.sol";
import "./resources/ERC2771Helper.sol";
import "./resources/CloneCreators.sol";
import "@opengsn/contracts/src/forwarder/Forwarder.sol"; // chose specific version to avoid import error: yarn add @opengsn/contracts@2.2.5

contract FeeSettingERC2771Test is Test {
    using ECDSA for bytes32; // for verify with var.recover()

    FeeSettings feeSettings;

    //Forwarder trustedForwarder;
    ERC2771Helper ERC2771helper;

    // DO NOT USE IN PRODUCTION! Key was generated online for testing only.
    uint256 public constant platformHotWalletPrivateKey =
        0x3c69254ad72222e3ddf37667b8173dd773bdbdfd93d4af1d192815ff0662de5f;
    address public platformHotWallet = vm.addr(platformHotWalletPrivateKey); // = 0x38d6703d37988C644D6d31551e9af6dcB762E618;

    address public constant mintAllower = 0x2109709EcFa91a80626Ff3989d68F67F5B1Dd122;
    address public constant relayer = 0x6109709EcFA91A80626FF3989d68f67F5b1dd126;

    address public constant receiver = 0x7109709eCfa91A80626Ff3989D68f67f5b1dD127;
    address public constant companyAdmin = 0x8109709ecfa91a80626fF3989d68f67F5B1dD128;
    address public constant sender = 0x9109709EcFA91A80626FF3989D68f67F5B1dD129;

    address public constant platformColdWallet = 0x3109709ECfA91A80626fF3989D68f67F5B1Dd123;
    address public constant feeCollector = 0x0109709eCFa91a80626FF3989D68f67f5b1dD120;

    uint32 public constant feeSettingsFeeDenominator = 100;
    uint32 public constant crowdinvestingFeeDenominator = 50;
    uint32 public constant privateOfferFeeDenominator = 70;

    Fees fees = Fees(1, feeSettingsFeeDenominator, 1, crowdinvestingFeeDenominator, 1, privateOfferFeeDenominator, 0);

    bytes32 domainSeparator;
    bytes32 requestType;

    function setUp() public {
        vm.prank(platformColdWallet);

        // deploy helper functions (only for testing with foundry)
        ERC2771helper = new ERC2771Helper();
    }

    function setUpFeeSettingsWithForwarder(Forwarder forwarder) public {
        // this is part of the platform setup, but we need it here to use the correct forwarder
        feeSettings = createFeeSettings(
            address(forwarder),
            platformColdWallet,
            fees,
            feeCollector,
            feeCollector,
            feeCollector
        );

        // make platform hot wallet a manager
        vm.prank(platformColdWallet);
        feeSettings.addManager(platformHotWallet);

        // log fee settings address
        console.log("feeSettings", address(feeSettings));

        // register domainSeparator with forwarder
        domainSeparator = ERC2771helper.registerDomain(
            forwarder,
            Strings.toHexString(uint256(uint160(address(feeSettings))), 20),
            "1"
        );

        // register request type with forwarder
        requestType = ERC2771helper.registerRequestType(forwarder, "mint", "address _to,uint256 _amount");
    }

    function testSetCustomFeeWithLocalForwarder(uint32 _customFeeDenominator, address _token) public {
        setCustomFeeWithERC2771(new Forwarder(), _customFeeDenominator, _token);
    }

    // function testSetCustomFeeWithMainnetGSNForwarder(uint32 _customFeeDenominator, address _token) public {
    //     // uses deployed forwarder on mainnet with fork. https://docs-v2.opengsn.org/networks/ethereum/mainnet.html
    //     setCustomFeeWithERC2771(
    //         Forwarder(payable(0xAa3E82b4c4093b4bA13Cb5714382C99ADBf750cA)),
    //         _customFeeDenominator,
    //         _token
    //     );
    // }

    function setCustomFeeWithERC2771(Forwarder _forwarder, uint32 _customFeeDenominator, address _token) public {
        vm.assume(_customFeeDenominator > 20);
        vm.assume(_token != address(0));
        setUpFeeSettingsWithForwarder(_forwarder);

        Fees memory customFees = Fees(
            1,
            _customFeeDenominator,
            1,
            crowdinvestingFeeDenominator,
            1,
            privateOfferFeeDenominator,
            100 * 365 days
        );

        /*
         * set custom fee
         */

        // 1. build request
        bytes memory payload = abi.encodeWithSelector(feeSettings.setCustomFee.selector, _token, customFees);

        IForwarder.ForwardRequest memory request = IForwarder.ForwardRequest({
            from: platformHotWallet,
            to: address(feeSettings),
            value: 0,
            gas: 1000000,
            nonce: _forwarder.getNonce(platformHotWallet),
            data: payload,
            validUntil: 0
        });

        // 2. pack and hash request
        bytes memory suffixData = "0";
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                domainSeparator,
                keccak256(_forwarder._getEncoded(request, requestType, suffixData))
            )
        );

        // 3. sign request
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(platformHotWalletPrivateKey, digest);
        bytes memory signature = abi.encodePacked(r, s, v); // https://docs.openzeppelin.com/contracts/2.x/utilities

        require(digest.recover(signature) == request.from, "FWD: signature mismatch");

        // 4. check state before execution
        (, uint32 feeDenominator, , , , , uint64 endTime) = feeSettings.customFees(_token);
        console.log("feeDenominator", feeDenominator);
        console.log("endTime", endTime);
        assertTrue(feeDenominator == 0, "Custom fee not 0 before");
        assertTrue(endTime == 0, "Custom fee not 0 before");

        // check platformHotWallet is a manager
        assertTrue(feeSettings.managers(platformHotWallet), "platformHotWallet is not a manager");
        assertFalse(address(_forwarder) == platformHotWallet, "platformHotWallet is forwarder");

        // 5.  execute request
        // send call through forwarder contract
        vm.prank(relayer);
        _forwarder.execute(request, domainSeparator, requestType, suffixData, signature);
        /*
            try to execute request again (must fail)
        */
        vm.expectRevert("FWD: nonce mismatch");
        _forwarder.execute(request, domainSeparator, requestType, suffixData, signature);

        // 6. check state after execution
        (, feeDenominator, , , , , endTime) = feeSettings.customFees(_token);
        console.log("feeDenominator", feeDenominator);
        console.log("endTime", endTime);
        assertTrue(feeDenominator == _customFeeDenominator, "Custom fee not set");
        assertTrue(endTime > 0, "Custom fee not set");
    }
}
