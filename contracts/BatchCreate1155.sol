// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
/**

 * @title Batch_create for Multiple nft
 * @dev Note its MultiipleNFT ERC1155 contract for batch selling  
 * 
 * 
 */

contract BatchCreate1155 is ERC1155 {
    address owner;
    // mapping type of nft 
    mapping(uint256 => uint256) nftType;
    // only owner can modify
    modifier onlyOwner() {
        require(msg.sender == owner, "not owner");
        _;
    }
   //Event to mint nft 
    event MintNFT(
        address to,
        uint256 _id,
        uint256 amount,
        bytes data
    );

    // event to mint batch 
    event MintBatchNFT(
        address to,
        uint256[] ids,
        uint256[] amounts,
        bytes data
    );
    //constructor takes owner and url link
    constructor(address _owner, string memory _url) ERC1155(_url) {
        require(bytes(_url).length > 0, "empty string not allowed");
        owner = _owner;
    }
    //function of mint single nft 
    function mintNFT(
        address to,
        uint256 _id,
        uint256 amount,
        bytes memory data
    ) external  
    {
        _mint(to, _id, amount, data);
        emit MintNFT(to, _id, amount, data);
    }
    // function to mintBatch
    function mintBatchNFT(
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) external 
    {

        _mintBatch(to, ids, amounts, data);

        emit MintBatchNFT(to, ids, amounts, data);
    }
}