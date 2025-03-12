// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.23;

import "../lib/forge-std/src/Test.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../contracts/Token.sol";
import "../contracts/Crowdinvesting.sol";
import "../contracts/PrivateOffer.sol";
import "../contracts/factories/PrivateOfferFactory.sol";
import "../contracts/FeeSettings.sol";
import "./resources/ERC20Helper.sol";

interface DaiLike is IERC20 {
    function PERMIT_TYPEHASH() external view returns (bytes32);

    function DOMAIN_SEPARATOR() external view returns (bytes32);

    function nonces(address owner) external view returns (uint256);

    function permit(
        address holder,
        address spender,
        uint256 nonce,
        uint256 expiry,
        bool allowed,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;
}

/**
 * @dev These tests need a mainnet fork of the blockchain, as they access contracts deployed on mainnet. Take a look at docs/testing.md for more information.
 */
contract MainnetCurrencies is Test {
    using SafeERC20 for IERC20;

    ERC20Helper helper = new ERC20Helper();

    uint256 public constant tokenOwnerPrivateKey = 0x3c69254ad72222e3ddf37667b8173dd773bdbdfd93d4af1d192815ff0662de5f;
    address public tokenOwner = vm.addr(tokenOwnerPrivateKey); // = 0x7109709eCfa91A80626Ff3989D68f67f5b1dD127;

    address public constant receiver = 0x7109709eCfa91A80626Ff3989D68f67f5b1dD127;

    // global variable because I am running out of local ones
    uint256 nonce;
    uint256 deadline;
    bytes32 PERMIT_TYPE_HASH;
    bytes32 DOMAIN_SEPARATOR;
    bytes32 structHash;

    function setUp() public {}

    function permitERC2612(
        ERC20Permit token,
        uint256 _tokenPermitAmount,
        uint256 _tokenTransferAmount,
        uint256 _tokenOwnerPrivateKey,
        address tokenSpender
    ) public {
        vm.assume(_tokenTransferAmount <= _tokenPermitAmount);
        tokenOwner = vm.addr(_tokenOwnerPrivateKey);
        helper.writeERC20Balance(tokenOwner, address(token), _tokenPermitAmount);

        // permit spender to spend holder's tokens
        nonce = token.nonces(tokenOwner);
        deadline = block.timestamp + 1000;
        PERMIT_TYPE_HASH = keccak256(
            "Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"
        );
        DOMAIN_SEPARATOR = token.DOMAIN_SEPARATOR();
        structHash = keccak256(
            abi.encode(PERMIT_TYPE_HASH, tokenOwner, tokenSpender, _tokenPermitAmount, nonce, deadline)
        );

        bytes32 hash = ECDSA.toTypedDataHash(DOMAIN_SEPARATOR, structHash);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(_tokenOwnerPrivateKey, hash);

        // verify signature
        require(tokenOwner == ECDSA.recover(hash, v, r, s), "invalid signature");

        // check allowance
        assertEq(token.allowance(tokenOwner, tokenSpender), 0, "allowance should be 0");

        // call permit as and address a that is not tokenOwner
        assertTrue(address(this) != tokenOwner, "address(this) must not be tokenOwner");
        token.permit(tokenOwner, tokenSpender, _tokenPermitAmount, deadline, v, r, s);

        // check allowance
        assertEq(
            token.allowance(tokenOwner, tokenSpender),
            _tokenPermitAmount,
            "allowance should be _tokenPermitAmount"
        );

        assertEq(
            token.balanceOf(tokenOwner),
            _tokenPermitAmount,
            "token balance of tokenOwner should be _tokenPermitAmount"
        );
        // store token balance of tokenSpender
        uint tokenSpenderBalanceBefore = token.balanceOf(tokenSpender);

        console.log("Tranfering %s tokens from %s to %s", _tokenPermitAmount, tokenOwner, tokenSpender);
        // spend tokens
        vm.prank(tokenSpender);
        token.transferFrom(tokenOwner, tokenSpender, _tokenTransferAmount);

        // check token balance of tokenSpender
        assertEq(
            token.balanceOf(tokenOwner),
            _tokenPermitAmount - _tokenTransferAmount,
            "token balance of tokenOwner should be _tokenPermitAmount - _tokenTransferAmount"
        );
        assertEq(
            token.balanceOf(tokenSpender),
            _tokenTransferAmount + tokenSpenderBalanceBefore,
            "token balance of tokenSpender should be _tokenTransferAmount"
        );
    }

    function testPermitMainnetEUROC() public {
        permitERC2612(ERC20Permit(address(EUROC)), 200, 123, tokenOwnerPrivateKey, receiver);
    }

    function testPermitMainnetUSDC() public {
        permitERC2612(ERC20Permit(address(USDC)), 200, 190, tokenOwnerPrivateKey, receiver);
    }

    /**
     * @dev This test takes into account the special permit implementation of DAI
     */
    function testPermitMainnetDAI() public {
        DaiLike token = DaiLike(address(DAI));
        uint256 _tokenPermitAmount = 200;
        uint256 _tokenTransferAmount = 70;
        tokenOwner = vm.addr(tokenOwnerPrivateKey);
        address tokenSpender = receiver;

        vm.assume(_tokenTransferAmount <= _tokenPermitAmount);
        tokenOwner = vm.addr(tokenOwnerPrivateKey);
        helper.writeERC20Balance(tokenOwner, address(token), _tokenPermitAmount);

        // permit spender to spend ALL OF the owner's tokens. This is the special case for DAI.
        bool allowed = true;
        nonce = token.nonces(tokenOwner);
        deadline = block.timestamp + 1000;
        DOMAIN_SEPARATOR = token.DOMAIN_SEPARATOR();
        structHash = keccak256(
            abi.encode(DaiLike(address(token)).PERMIT_TYPEHASH(), tokenOwner, tokenSpender, nonce, deadline, allowed)
        );

        bytes32 hash = ECDSA.toTypedDataHash(DOMAIN_SEPARATOR, structHash);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(tokenOwnerPrivateKey, hash);

        // verify signature
        require(tokenOwner == ECDSA.recover(hash, v, r, s), "invalid signature");

        // check allowance
        assertEq(token.allowance(tokenOwner, tokenSpender), 0, "allowance should be 0");

        // call permit as and address a that is not tokenOwner
        assertTrue(address(this) != tokenOwner, "address(this) must not be tokenOwner");

        DaiLike(address(token)).permit(tokenOwner, tokenSpender, nonce, deadline, true, v, r, s);

        // check allowance
        assertEq(token.allowance(tokenOwner, tokenSpender), UINT256_MAX, "allowance should be UINT256_MAX");

        assertEq(
            token.balanceOf(tokenOwner),
            _tokenPermitAmount,
            "token balance of tokenOwner should be _tokenPermitAmount"
        );
        // store token balance of tokenSpender
        uint tokenSpenderBalanceBefore = token.balanceOf(tokenSpender);

        console.log("Tranfering %s tokens from %s to %s", _tokenPermitAmount, tokenOwner, tokenSpender);
        // spend tokens
        vm.prank(tokenSpender);
        token.transferFrom(tokenOwner, tokenSpender, _tokenTransferAmount);

        // check token balance of tokenSpender
        assertEq(
            token.balanceOf(tokenOwner),
            _tokenPermitAmount - _tokenTransferAmount,
            "token balance of tokenOwner should be _tokenPermitAmount - _tokenTransferAmount"
        );
        assertEq(
            token.balanceOf(tokenSpender),
            _tokenTransferAmount + tokenSpenderBalanceBefore,
            "token balance of tokenSpender should be _tokenTransferAmount"
        );
    }

    // sadly, WETH and WBTC seem not to support permit or an equivalent meta transaction
}
