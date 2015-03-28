module tharsis.prof.compat;

static if(__VERSION__ < 2066)
    public enum nogc;