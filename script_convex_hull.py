#!/usr/bin/env python
# -*- coding: utf-8 -*-

import numpy as np, matplotlib.pyplot as plt, pylab as p, time, sys
from scipy.spatial import ConvexHull
from scipy.stats import pearsonr

class snapshot:
    def __init__(self):
        self.interval = 0
        self.id = 0
        self.points = 0
        self.area = 0
        self.peso = 0
        self.peso_prom = 0
        self.hull = 0

class interval:
    def __init__(self):
        self.id = 0
        self.agents = 0

def get_intervals(inter):
    # extraigo del csv las marcas
    m = np.loadtxt(open("salida-movimientos.csv","rb"),delimiter=";",skiprows=0)

    # busco la cantidad de ranas y el ultimo tic
    # sumo 1 por el index empieza en 0
    cant_ranas = m[:,1].max() + 1
    max_tic = m[:, 0].max() + 1

    # divido el csv por la cantidad de intervalos
    # notese que el csv ya está ordenado por tics
    matrix_by_intervals = np.vsplit(m, int(inter))

    # vector vacío para devolver los intervalos
    intervals = np.zeros(len(matrix_by_intervals), dtype=object)

    i = 0
    for m in matrix_by_intervals:
        # ordeno el intervalo por id de agente
        interval_by_agents = m[np.argsort(m[:,1])]
        
        # divido por la cantidad de agentes
        interval_by_agents = np.vsplit(interval_by_agents, cant_ranas)

        # vector vacío para ir procesando agentes de un intervalo
        agents_interval = np.zeros(len(interval_by_agents), dtype=object)
        j = 0
        
        # proceso cada agente en un objeto snapshot
        for a in interval_by_agents:
            s = snapshot()
            s.interval = i
            s.id = int(a[0, 1])
            s.peso = a[np.argsort(a[:,0])][-1, 4]
            s.peso_prom = np.average(a[:, 4])
            s.points = a[:, [2,3]]
            agents_interval[j] = s
            j = j + 1

        inter = interval()
        inter.id = i
        inter.agents = agents_interval[:]
        intervals[i] = inter
        i = i + 1    
    return intervals

def poly_area(x, y):
    return 0.5*np.abs(np.dot(x,np.roll(y,1))-np.dot(y,np.roll(x,1)))
             
def process_interval(i):
    for agent in i.agents:
        agent = process_snap(agent)
        
def process_snap(s):
    points = s.points
    hull = ConvexHull(points)
    s.hull = hull
    s.area = poly_area(points[hull.vertices, 0], points[hull.vertices, 1])
    return s

def plot_intervals(i):
    for interval in i:
        plt.figure(interval.id)
        for agent in interval.agents:
            points = agent.points
            hull = agent.hull
            plt.plot(points[:,0], points[:,1], 'o')
            for simplex in hull.simplices:
                plt.plot(points[simplex, 0], points[simplex, 1], 'k-')
    plt.show()

if __name__ == "__main__":
    inter = sys.argv[1]
    intervals = get_intervals(inter)

    c = 0
    for interval in intervals:
        process_interval(interval)

    area = np.zeros(len(intervals))
    peso = np.zeros(len(intervals))
    c = 0

    for x in range(0, len(intervals[0].agents)):
        c = 0
        for i in intervals:
            area[c] = i.agents[x].area
            peso[c] = i.agents[x].peso_prom
            #print(i.agents[x].interval, i.agents[x].id, i.agents[x].area, i.agents[x].peso, i.agents[x].peso_prom)
            c = c + 1
        p = pearsonr(peso, area)
        print("Pearson rana # " + str(x) + " peso_prom, area: " +  str(p))
        #plot_intervals(intervals)
