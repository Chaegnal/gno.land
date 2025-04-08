package group

import (
	"strconv"
	"strings"

	"gno.land/p/sunspirit/md"
	"gno.land/r/chaegnal/organizer"
)

func parseQuery(url string) string {
	groupId := strings.SplitAfter(url, "?")
	foundId := strings.SplitAfter(groupId[1], "=")

	return foundId[1]
}

func getGroupFromUrl(url string) organizer.FriendGroup {
	groupId := parseQuery(url)
	if groupId == "" {
		panic("No groupId provided")
	}

	convertedId, err := strconv.Atoi(groupId)
	if err != nil {
		panic("Invalid ID")
	}

	raw, found := organizer.ListGroups.Groups.Get(strconv.Itoa(convertedId))
	if !found {
		panic("Could not find group")
	}

	return raw.(organizer.FriendGroup)
}

func Render(url string) string {
	var out string

	group := getGroupFromUrl(url)

	out += md.H1("Group: " + group.Title)
	out += md.H2("Created by: " + organizer.ResolveAddressName(group.Owner.Owner()))
	out += md.Paragraph("Number of friends: " + strconv.Itoa(group.Friends.Size()))

	return out
}
