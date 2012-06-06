#!/bin/sh

# show how the current terminal responds to various ANSI queries
#
# see http://paperlined.org/apps/terminals/queries.html


echo "======== query cursor position ========"
./ansi_reply.pl  '\e[6n' R
echo


echo "======== query device status ========"
./ansi_reply.pl  '\e[5n' n
echo


echo "======== query printer status ========"
./ansi_reply.pl  '\e[?15n' n
echo


echo "======== query device attributes ========"
./ansi_reply.pl  '\e[c' c
echo


echo "======== ENQ (enquire) / answerback ========"
./ansi_reply.pl  '\005'
