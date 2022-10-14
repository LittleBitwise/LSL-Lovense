integer gRows = 20;
integer gCols = 20;

vector size;
vector size2;

vector snap;
float rowSnap;
float rowSnap2;
float colSnap;
float colSnap2;

initRowsCols(integer rows, integer cols) {
    if (rows < 1) rows = 1;
    if (cols < 1) cols = 1;

    gRows = rows + 1; // Always include "zero" setting.
    gCols = cols;

    rowSnap = (1.0 / gRows); rowSnap2 = (rowSnap / 2);
    colSnap = (1.0 / gCols); colSnap2 = (colSnap / 2);

    // Reset slider positions.
    list position = [PRIM_POS_LOCAL, <0.05,0,0>];
    integer i; for (i=2; i < 2+gCols; ++i) {
        vector pos = getSurfaceGridPosition(<(i-2) * colSnap, 0, 0>);
        position += [PRIM_LINK_TARGET, i, PRIM_POS_LOCAL, pos];
    }

    llSetLinkPrimitiveParamsFast(LINK_ALL_CHILDREN, position);
}

vector getSurfaceGridPosition(vector surface) {
    integer col = (integer)(surface.x * gCols);
    integer row = (integer)(surface.y * gRows);

    // Snap to grid.
    surface.x = (col * colSnap) + colSnap2;
    surface.y = (row * rowSnap) + rowSnap2;

    // Scale for size.
    surface.x *= size.x;
    surface.y *= size.y;

    // Slider position.
    vector v1 = <0, -surface.x, surface.y>;
    vector v2 = <0, -size2.x, size2.y>;
    vector pos = v1 - v2;

    llSetText((string)[
        surface," (",col,"|",row,")\n",
        v1, "\n",
        v2, "\n",
        pos
    ], <1,1,1>, 1);

    return pos;
}

default
{
    state_entry()
    {
        size = llGetScale();
        size = <size.y, size.z, 0>; // TouchST order
        size2 = <(size.x / 2), (size.y / 2), 0>;

        initRowsCols(5, 10);

        llListen(0, "", "", "send");
    }

    touch(integer n)
    {
        if (llDetectedLinkNumber(0) != 1) return;

        vector surface = llDetectedTouchST(0);
        if (surface == <-1, -1, 0>) return;

        integer col = (integer)(surface.x * gCols);
        vector pos = getSurfaceGridPosition(surface);

        llSetLinkPrimitiveParamsFast(2 + col, [PRIM_POS_LOCAL, pos]);
    }

    listen(integer channel, string name, key id, string message)
    {
        // TODO: Send slider data to relay.
    }
}
