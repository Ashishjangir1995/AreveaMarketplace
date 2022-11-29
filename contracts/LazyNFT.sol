//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.4;
pragma abicoder v2; // required to accept structs as function parameters

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/draft-EIP712.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract LazyNFT is ERC721URIStorage, EIP712 {
    string private constant names = "LazyNFTMinting-signature";
    string private constant version = "1";
    uint256 public chainId = 43113;

    IERC20 private token;

    event LazyMint(address indexed seller, address buyer, uint256 salePrice);

    constructor(address _token)
        ERC721("LazyNFT", "LAZ")
        EIP712(names, version)
    {
        token = IERC20(_token);
    }

    /// @notice Represents an un-minted NFT, which has not yet been recorded into the blockchain. A signed voucher can be redeemed for a real NFT using the redeem function.
    struct Permit {
        /// @notice The id of the token to be redeemed. Must be unique - if another token with this ID already exists, the redeem function will revert.
        uint256 tokenId;
        /// @notice The minimum price (in wei) that the NFT creator is willing to accept for the initial sale of this NFT.
        uint256 minPrice;
        /// @notice The metadata URI to associate with this token.
        string uri;
        /// @notice the EIP-712 signature of all other fields in the Permit struct. For a voucher to be valid, it must be signed by an account with the MINTER_ROLE.
        bytes signature;
    }

    /// @notice Redeems an Permit for an actual NFT, creating it in the process.
    /// @param redeemer The address of the account which will receive the NFT upon success.
    /// @param voucher A signed Permit that describes the NFT to be redeemed.
    function redeem(
        address redeemer,
        uint8 v,
        bytes32 r,
        bytes32 s,
        uint256 amount,
        Permit calldata voucher
    ) public payable   
    {
        // make sure signature is valid and get the address of the signer
        address signer = executeSetIfSignatureMatch(v, r, s, voucher);

        // make sure that the redeemer is paying enough to cover the buyer's cost
        require(amount >= voucher.minPrice, "Insufficient funds to redeem");

        // first assign the token to the signer, to establish provenance on-chain
        _mint(signer, voucher.tokenId);
        _setTokenURI(voucher.tokenId, voucher.uri);

        // transfer the NFT token to the redeemer
        _transfer(signer, redeemer, voucher.tokenId);

        //irc20 interwrap wrap transfer token
        token.transferFrom(redeemer, signer, voucher.minPrice);

        emit LazyMint(signer, redeemer, voucher.minPrice);
    }

    function executeSetIfSignatureMatch(
        uint8 v,
        bytes32 r,
        bytes32 s,
        Permit calldata voucher
    ) public view returns (address) {
        bytes32 eip712DomainHash = keccak256(
            abi.encode(
                keccak256(
                    "EIP712Domain(string names,string version,uint256 chainId)"
                ),
                keccak256(bytes("LazyNFTMinting-signature")),
                keccak256(bytes("1")),
                chainId
            )
        );

        bytes32 hashStruct = keccak256(
            abi.encode(
                keccak256(
                    "Permit(uint256 tokenId,uint256 minPrice,string uri)"
                ),
                voucher.tokenId,
                voucher.minPrice,
                keccak256(bytes(voucher.uri))
            )
        );

        bytes32 hash = keccak256(
            abi.encodePacked("\x19\x01", eip712DomainHash, hashStruct)
        );
        address signer = ecrecover(hash, v, r, s);
        return signer;
    }

    function getChainID() external view returns (uint256) {
        uint256 id;
        assembly {
            id := chainid()
        }
        return id;
    }

}
