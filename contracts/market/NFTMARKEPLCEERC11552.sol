// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./INFTMarketplace1155.sol";
import "./ANFTMarketplace1155.sol";
import "./AmountTransfer.sol";

contract NFTMarketplace1155 is INFTMarketplace1155, ANFTMarketplace1155 {
    using SafeMath for uint256;

    constructor(address _owner, uint256 _makerFee) {
        owner = _owner;
        makerFee = _makerFee;
    }

    // owner Function

    function setMakerFee(uint256 _makerFee) external onlyOwner {
        makerFee = _makerFee;
    }

    function setOwner(address _owner) external onlyOwner {
        owner = _owner;
        emit UpdateOwner(msg.sender, _owner);
    }

    // NFT FIXED SALE

    function nftFixedSale(
        FixedSale memory fixedSale,
        address _nftContractAddress,
        uint256 _tokenId,
        bytes memory _data
    )
        external
        isSaleStartByOwner(_nftContractAddress, _tokenId)
        isContractApprove(_nftContractAddress, _tokenId)
        isAmountAvaible(_nftContractAddress, fixedSale.amount, _tokenId)
        priceGreaterThanZero(fixedSale.salePrice)
    {
        FixedSale memory _fixedSale = fixedSale;
        bytes memory data = _data;

        _nftFixedSaleDetails(
            _nftContractAddress, // nft address 
            _fixedSale.erc20,  // erc 20 
            _fixedSale.royaltyReciever,// any address 
            _tokenId,// token id 
            _fixedSale.amount, //5 
            _fixedSale.salePrice,// price 50 
            _fixedSale.royalty,// amount 2
            data
        );
    }

    function cancelFixedsale(
        address _nftContractAddress,
        uint256 _tokenId,
        uint256 _amount,
        uint256 _leftAmount,
        bytes memory _data
    )
        external
        isNftAmountInSale(_nftContractAddress, _tokenId, _amount)
        isSaleResetByOwner(_nftContractAddress, _tokenId, _amount)
    {
        require(
            nftContractFixedSale[_nftContractAddress][_tokenId][_amount]
                .amount >= _leftAmount,
            "nft amount not exist"
        );
        address nftSeller = nftContractFixedSale[_nftContractAddress][_tokenId][
            _amount
        ].nftSeller;
        IERC1155(_nftContractAddress).safeTransferFrom(
            address(this),
            nftSeller,
            _tokenId,
            _leftAmount,
            _data
        );

        nftContractFixedSale[_nftContractAddress][_tokenId][_amount]
            .amount -= _leftAmount;

        inSale[msg.sender][_nftContractAddress][_tokenId] -= _leftAmount;
        totalAmountInSale[_nftContractAddress][_tokenId] -= _leftAmount;

        if (totalAmountInSale[_nftContractAddress][_tokenId] == 0) {
            delete fixedSaleNFT[
                (indexFixedSaleNFT[_nftContractAddress][_tokenId])
            ];
        }

        emit CancelNftFixedSale(_nftContractAddress, msg.sender, _tokenId);
    }

    function updateFixedSalePrice(
        address _nftContractAddress,
        uint256 _tokenId,
        uint256 _updateSalePrice,
        uint256 _amount
    )
        external
        isNftAmountInSale(_nftContractAddress, _tokenId, _amount)
        isSaleResetByOwner(_nftContractAddress, _tokenId, _amount)
        priceGreaterThanZero(_updateSalePrice)
    {
        require(
            nftContractFixedSale[_nftContractAddress][_tokenId][_amount]
                .salePrice != 0,
            "not exist"
        );

        nftContractFixedSale[_nftContractAddress][_tokenId][_amount]
            .salePrice = _updateSalePrice;

        emit NftFixedSalePriceUpdated(
            _nftContractAddress,
            _tokenId,
            _updateSalePrice
        );
    }

    function buyFromFixedSale(
        address _nftContractAddress,
        uint256 _tokenId,
        uint256 _amount,
        uint256 _nftAmount,
        uint256 _leftAmount,
        bytes memory _data
    )
        external
        payable
        priceGreaterThanZero(_amount)
        buyPriceMeetSalePrice(
            _nftContractAddress,
            _tokenId,
            _amount,
            _nftAmount,
            _leftAmount
        )
    {
        require(
            nftContractFixedSale[_nftContractAddress][_tokenId][_nftAmount]
                .amount >= _leftAmount,
            "nft amount not exist"
        );
        require(_nftAmount != 0, "non-zero value or amount not greater");

        require(
            nftContractFixedSale[_nftContractAddress][_tokenId][_nftAmount]
                .salePrice != 0,
            "not exist"
        );

        _fixedBuy(
            _nftContractAddress,
            _tokenId,
            _amount,
            _nftAmount,
            _leftAmount,
            _data
        );
    }

    // NFT AUCTION SALE

    function createNftAuctionSale(
        Auction memory _auction,
        bytes memory _data,
        address _nftContractAddress,
        uint256 _tokenId
    )
        external
        isSaleStartByOwner(_nftContractAddress, _tokenId)
        isNftAlreadyInSale(_nftContractAddress, _tokenId)
        isContractApprove(_nftContractAddress, _tokenId)
        priceGreaterThanZero(_auction.minPrice)
    {
        require(_auction.nftAmount != 0, "zero invalid");

        Auction memory auction = _auction;
        bytes memory data = _data;

        _storedNftAuctionDetails(
            _nftContractAddress,
            auction.erc20,
            auction.royaltyReciever,
            _tokenId,
            auction.auctionStart,
            auction.auctionEnd,
            auction.minPrice,
            auction.nftAmount,
            auction.royalty,
            data
        );
    }

    function makeBid(
        address _nftContractAddress,
        uint256 _tokenId,
        uint256 _bidPrice
    )
        external
        payable
        isNftInAuctionSale(_nftContractAddress, _tokenId)
        isAuctionOngoing(_nftContractAddress, _tokenId)
        priceGreaterThanZero(_bidPrice)
        islatestBidGreaterPreviousOne(
            _nftContractAddress,
            _tokenId,
            msg.value,
            _bidPrice
        )
    {
        if (
            nftContractAuctionSale[_nftContractAddress][_tokenId].erc20 !=
            address(0)
        ) {
            AmountTransfer.bidAmountTransfer(
                _bidPrice,
                nftContractAuctionSale[_nftContractAddress][_tokenId].erc20,
                msg.sender
            );
        }

        nftContractAuctionSale[_nftContractAddress][_tokenId]
            .nftHighestBid = _bidPrice;
        nftContractAuctionSale[_nftContractAddress][_tokenId]
            .nftHighestBidder = msg.sender;

        userBidPriceOnNFT[_nftContractAddress][_tokenId][
            msg.sender
        ] = _bidPrice;

        emit NftBidPrice(_nftContractAddress, _tokenId, _bidPrice, msg.sender);
    }

    function updateTheBidPrice(
        address _nftContractAddress,
        uint256 _tokenId,
        uint256 _updateBidPrice
    )
        external
        payable
        isNftInAuctionSale(_nftContractAddress, _tokenId)
        isAuctionOngoing(_nftContractAddress, _tokenId)
        priceGreaterThanZero(_updateBidPrice)
        isUpdatedBidGreaterPreviousOne(
            _nftContractAddress,
            _tokenId,
            msg.value,
            _updateBidPrice
        )
    {
        address nftContractAddress = _nftContractAddress;
        uint256 tokenId = _tokenId;
        uint256 finalBidPrice = userBidPriceOnNFT[nftContractAddress][tokenId][
            msg.sender
        ].add(_updateBidPrice);

        if (
            nftContractAuctionSale[nftContractAddress][tokenId].erc20 !=
            address(0)
        ) {
            AmountTransfer.bidAmountTransfer(
                _updateBidPrice,
                nftContractAuctionSale[nftContractAddress][tokenId].erc20,
                msg.sender
            );
        }

        nftContractAuctionSale[nftContractAddress][tokenId]
            .nftHighestBid = finalBidPrice;
        nftContractAuctionSale[nftContractAddress][tokenId]
            .nftHighestBidder = msg.sender;

        userBidPriceOnNFT[nftContractAddress][tokenId][
            msg.sender
        ] = finalBidPrice;

        emit NftAuctionBidPriceUpdate(
            nftContractAddress,
            tokenId,
            finalBidPrice,
            msg.sender
        );
    }

    function _cancelAuctionSale(address _nftContractAddress, uint256 _tokenId)
        external
        isNftInAuctionSale(_nftContractAddress, _tokenId)
        isAuctionResetByOwner(_nftContractAddress, _tokenId)
        isAuctionOngoing(_nftContractAddress, _tokenId)
        isbidNotMakeTillNow(_nftContractAddress, _tokenId)
    {
        address nftContractAddress = _nftContractAddress;
        uint256 tokenId = _tokenId;

        nftSaleStatus[_nftContractAddress][_tokenId] = 0;

        IERC1155(_nftContractAddress).safeTransferFrom(
            address(this),
            msg.sender,
            _tokenId,
            nftContractAuctionSale[nftContractAddress][tokenId].nftAmount,
            ""
        );

        delete auctionSaleNFT[
            (indexAuctionSaleNFT[_nftContractAddress][_tokenId])
        ];

        emit CancelNftAuctionSale(_nftContractAddress, _tokenId, msg.sender);
    }

    function settleAuction(address _nftContractAddress, uint256 _tokenId)
        external
        isNftInAuctionSale(_nftContractAddress, _tokenId)
        isAuctionOver(_nftContractAddress, _tokenId)
    {
        address nftBuyer = nftContractAuctionSale[_nftContractAddress][_tokenId]
            .nftHighestBidder;

        _transferNftAndPaySeller(
            _nftContractAddress,
            _tokenId,
            nftContractAuctionSale[_nftContractAddress][_tokenId].nftHighestBid,
            nftBuyer
        );

        userBidPriceOnNFT[_nftContractAddress][_tokenId][nftBuyer] = 0;
        delete auctionSaleNFT[
            (indexAuctionSaleNFT[_nftContractAddress][_tokenId])
        ];

        emit NftAuctionSettle(
            _nftContractAddress,
            _tokenId,
            nftBuyer,
            nftContractAuctionSale[_nftContractAddress][_tokenId].nftHighestBid,
            nftContractAuctionSale[_nftContractAddress][_tokenId].nftSeller
        );
    }

    function withdrawBid(address _nftContractAddress, uint256 _tokenId)
        external
        //isAuctionOver(_nftContractAddress, _tokenId)
    {
        require(
            msg.sender !=
                nftContractAuctionSale[_nftContractAddress][_tokenId]
                    .nftHighestBidder,
            "You are highest bidder"
        );
        require(
            userBidPriceOnNFT[_nftContractAddress][_tokenId][msg.sender] > 0,
            "nothing to withdraw"
        );

        uint256 amount = userBidPriceOnNFT[_nftContractAddress][_tokenId][
            msg.sender
        ];
        address _erc20 = nftContractAuctionSale[_nftContractAddress][_tokenId]
            .erc20;

        if (_erc20 != address(0)) {
            IERC20(_erc20).transfer(msg.sender, amount);
        } else {
            AmountTransfer.nativeAmountTransfer(msg.sender, amount);
        }

        userBidPriceOnNFT[_nftContractAddress][_tokenId][msg.sender] = 0;

        emit withdrawNftBid(_nftContractAddress, _tokenId, msg.sender);
    }

    function onERC1155Received(
        address _operator,
        address _from,
        uint256 _id,
        uint256 _value,
        bytes calldata _data
    ) external pure returns (bytes4) {
        return 0xf23a6e61;
    }

    function onERC1155BatchReceived(
        address _operator,
        address _from,
        uint256[] calldata _ids,
        uint256[] calldata _values,
        bytes calldata _data
    ) external pure returns (bytes4) {
        return 0xbc197c81;
    }

    receive() external payable {}
}
